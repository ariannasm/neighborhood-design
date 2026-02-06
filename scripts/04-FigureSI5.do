* ==================================================================
* Figure SI5: GCD components by year and distance
* ==================================================================
*
* Description: Creates a combined figure for the 4 GCD components showing:
*   - Panel A: Trend over time (by first year built)
*   - Panel B: Trend by distance to city center, split by vintage
*
* Inputs (from data/clean):
*   - us_data_matching.dta
*
* Outputs (to figures):
*   - fig_SI5.pdf
*
* ==================================================================

clear all
set more off

* ------------------------------------------------------------------
* Setup: Set replication path (MODIFY THIS PATH FOR YOUR SYSTEM)
* ------------------------------------------------------------------

* UPDATE THIS PATH to your local Replication folder
global replication_path "/path/to/Replication"

* Define subdirectories
global data_clean "${replication_path}/data/clean"
global figures "${replication_path}/figures"

* ------------------------------------------------------------------
* Define color palette
* ------------------------------------------------------------------

global orange_light ""231 151 80""
global orange_dark ""243 102 40""
global orange_dark_op ""243 102 40%30""
global blue_light ""87 158 190""
global blue_light_med ""74 114 173""
global blue_med ""69 80 141""
global blue_dark ""51 48 99""

global blue_med_op ""130 130 130%20""
global blue_dark_op ""51 48 99%20""
global orange_light_op ""231 151 80%20""
global blue_light_med_op ""74 114 173%20""
global blue_med_op ""69 80 141%20""

graph set window fontface "Helvetica"
graph set ps fontface "Helvetica"

* ==================================================================
* SECTION 1: Load data
* ==================================================================

use "${data_clean}/us_data_matching.dta", clear

* Keep only neighborhoods within 45km of city center
keep if dist_2000_city_altpop_km <= 45

* ==================================================================
* SECTION 2: Loop over GCD components
* ==================================================================

local i = 1

foreach yvar in std_osm_curvaturep75 std_osm_threeway_inter std_osm_share_angle90 std_osm_out_street {

    global depvar `yvar'

    * Set figure title based on component
    if "$depvar" == "std_osm_curvaturep75" {
        local ltit "Curvilinear streets"
    }
    if "$depvar" == "std_osm_threeway_inter" {
        local ltit "Street hierarchy"
    }
    if "$depvar" == "std_osm_share_angle90" {
        local ltit "Block organicity"
    }
    if "$depvar" == "std_osm_out_street" {
        local ltit "Enclosed streets"
    }

    * ------------------------------------------------------------------
    * Panel A: Component trend over time
    * ------------------------------------------------------------------

    preserve

    collapse (count) ${depvar}_count = ${depvar} ///
             (sd) ${depvar}_sd = ${depvar} ///
             (mean) ${depvar}_mean = ${depvar}, by(first_year_built)

    * Compute 95% confidence interval
    gen ci_high = ${depvar}_mean + 1.96 * ${depvar}_sd / sqrt(${depvar}_count)
    gen ci_low = ${depvar}_mean - 1.96 * ${depvar}_sd / sqrt(${depvar}_count)

    tsset first_year_built

    twoway (connected ${depvar}_mean first_year_built, ///
            color(${blue_dark}) msymbol(circle) msize(small)), ///
        ytitle("`ltit'", size(5)) ///
        xtitle("Years", size(5)) ///
        ylabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
        xlabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(lcolor(black) lwidth(thin)) ///
        xsize(5) ysize(4) scale(1) ///
        legend(off) ///
        name(ptime_`i', replace)

    restore

    * ------------------------------------------------------------------
    * Panel B: Component by distance, split by vintage
    * ------------------------------------------------------------------

    preserve

    gen bins = floor(dist_2000_city_altpop_km / 1) * 1

    collapse (count) ${depvar}_count = ${depvar} ///
             (sd) ${depvar}_sd = ${depvar} ///
             (mean) ${depvar}, by(bins vintage_*)

    rangestat (mean) m_${depvar}_sd = ${depvar}_sd ///
                     m_${depvar}_count = ${depvar}_count ///
                     m_$depvar = $depvar, interval(bins -2 2) by(vintage_*)

    * Compute 95% confidence interval
    gen ci_high = m_${depvar} + 1.96 * m_${depvar}_sd / sqrt(m_${depvar}_count)
    gen ci_low = m_${depvar} - 1.96 * m_${depvar}_sd / sqrt(m_${depvar}_count)

    * Conditional legend: only show on first panel (top row)
    if `i' == 1 {
        local legend_opt `"legend(region(fc("255 255 255%80") lwidth(none)) pos(11) ring(0) rows(1) keygap(0.3) colgap(0.8) size(small) symysize(0.6) symxsize(3) order(1 "1900-1925" 2 "1926-1950" 3 "1951-1975" 4 "1976-2000"))"'
    }
    else {
        local legend_opt "legend(off)"
    }

    twoway (connected m_$depvar bins if vintage_1900_1925 == 1, ///
                color(${orange_dark}) msymbol(circle) msize(small)) ///
           (connected m_$depvar bins if vintage_1926_1950 == 1, ///
                color(${blue_light}) msymbol(circle) msize(small)) ///
           (connected m_$depvar bins if vintage_1951_1975 == 1, ///
                color(${blue_med}) msymbol(circle) msize(small)) ///
           (connected m_$depvar bins if vintage_1976_2000 == 1, ///
                color(${blue_dark}) msymbol(circle) msize(small)), ///
        ytitle("", size(5)) ///
        xtitle("Distance To Main City (km)", size(5)) ///
        ylabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
        xlabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
        graphregion(color(white)) bgcolor(white) ///
        plotregion(lcolor(black) lwidth(thin)) ///
        `legend_opt' ///
        xsize(5) ysize(4) scale(1) ///
        name(pdist_`i', replace)

    restore

    local i = `i' + 1
}

* ==================================================================
* SECTION 3: Combine all panels into single figure
* ==================================================================

* Combine: 4 rows (one per component), 2 columns (time, distance)
gr combine ptime_1 pdist_1 ptime_2 pdist_2 ptime_3 pdist_3 ptime_4 pdist_4, ///
    graphregion(color(white)) plotregion(fcolor(white)) ///
    rows(4) cols(2) ///
    xsize(10) ysize(14) ///
    name(combined, replace)

graph export "${figures}/fig_SI5.pdf", as(pdf) replace

di _n "=============================================="
di "Figure SI3 complete."
di "Output saved to: ${figures}/fig_SI5.pdf"
di "=============================================="
