* ==================================================================
* Figure 1: GCD index distribution
* ==================================================================
*
* Description: Creates a panel figure showing:
*   A) GCD distribution over time (by decade)
*   B) GCD by distance to main city, by vintage
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - fig_1.pdf
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
* Set graph fonts
* ------------------------------------------------------------------

graph set window fontface "Helvetica"
graph set ps fontface "Helvetica"

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

* ------------------------------------------------------------------
* Define main variable
* ------------------------------------------------------------------

global gdi garden_metric_osm
local ltit "GCD"

* Distance variable
local distance dist_2000_city_altpop_km

* ==================================================================
* SECTION 1: Load data
* ==================================================================

use "${data_clean}/us_data_matching.dta", clear 

* ------------------------------------------------------------------
* Compute summary statistics
* ------------------------------------------------------------------

sum ${gdi}, d
local us_value = `r(mean)'
local us_n = `r(N)'
local percentile = round(`r(N)'/`us_n', .01)
gen us_value = `r(mean)'

* ==================================================================
* SECTION 2: Panel A - GCD Distribution Over Time
* ==================================================================

preserve

* Create decade bins
gen bins = floor(first_year_built/10)*10

* Collapse to decade level
collapse (count) ${gdi}_count = ${gdi} ///
         (sd) ${gdi}_sd = ${gdi} ///
         (mean) ${gdi}, by(bins)

* Compute 95% confidence interval
gen ci_high = ${gdi} + 1.96 * ${gdi}_sd / sqrt(${gdi}_count)
gen ci_low = ${gdi} - 1.96 * ${gdi}_sd / sqrt(${gdi}_count)

* Set time series
tsset bins

* Create plot
twoway (rarea ci_low ci_high bins, color(${blue_dark_op}) lwidth(vvthin)) ///
       (connected ${gdi} bins, mcolor(${blue_dark}) msymbol(circle) ///
                              msize(small) lcolor(${blue_dark}) lwidth(medium)), ///
    graphregion(color(white)) bgcolor(white) ///
    xsize(5) ysize(5) scale(1) ///
    ylabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
    xlabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
    yscale(lstyle(none)) ///
    xscale(lstyle(none)) ///
    plotregion(lcolor(black) lwidth(thin)) ///
    xtitle("Years", size(5) margin(small)) ///
    ytitle("`ltit'", size(5)) ///
    title("{bf:A}", justification(left) position(11) size(6) span) ///
    legend(off) ///
    name(p_time, replace)

restore

* ==================================================================
* SECTION 3: Panel B - GCD by Distance to City, by Vintage
* ==================================================================

preserve

* Keep only neighborhoods within 45 km of main city
keep if `distance' <= 45


* Create 2 km distance bins
gen bins = floor(`distance'/2)*2

* Collapse by distance bin and vintage
collapse (count) ${gdi}_count = ${gdi} ///
         (sd) ${gdi}_sd = ${gdi} ///
         (mean) garden_metric_mean = ${gdi}, by(bins vintage_*)

* Compute rolling averages (smoothing)
rangestat (mean) m_${gdi}_sd = ${gdi}_sd ///
                 m_${gdi}_count = ${gdi}_count ///
                 m_garden_metric_mean = garden_metric_mean, ///
          interval(bins -2 2) by(bins vintage_*)

* Compute 95% confidence interval
gen ci_high = m_garden_metric_mean + 1.96 * m_${gdi}_sd / sqrt(m_${gdi}_count)
gen ci_low = m_garden_metric_mean - 1.96 * m_${gdi}_sd / sqrt(m_${gdi}_count)


* Create plot
twoway (rarea ci_low ci_high bins if vintage_1900_1925==1, ///
            color(${orange_light_op}) lwidth(vvthin)) ///
       (connected m_garden_metric_mean bins if vintage_1900_1925==1, ///
            color(${orange_light}) msymbol(circle) msize(small)) ///
       (rarea ci_low ci_high bins if vintage_1926_1950==1, ///
            color(${blue_light_med_op}) lwidth(vvthin)) ///
       (connected m_garden_metric_mean bins if vintage_1926_1950==1, ///
            color(${blue_light_med}) msymbol(circle) msize(small)) ///
       (rarea ci_low ci_high bins if vintage_1951_1975==1, ///
            color(${blue_med_op}) lwidth(vvthin)) ///
       (connected m_garden_metric_mean bins if vintage_1951_1975==1, ///
            color(${blue_med}) msymbol(circle) msize(small)) ///
       (rarea ci_low ci_high bins if vintage_1976_2000==1, ///
            color(${blue_dark_op}) lwidth(vvthin)) ///
       (connected m_garden_metric_mean bins if vintage_1976_2000==1, ///
            color(${blue_dark}) msymbol(circle) msize(small)), ///
    graphregion(color(white)) bgcolor(white) ///
    xsize(5) ysize(5) scale(1) ///
    yscale(range(0.3 0.6) lstyle(none)) ///
    xscale(lstyle(none)) ///
    ylabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
    xlabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
    plotregion(lcolor(black) lwidth(thin)) ///
    xtitle("Distance to main city (Km)", size(5)) ///
    ytitle("`ltit'", size(5)) ///
    title("{bf:B}", justification(left) position(11) size(6) span) ///
    legend(region(lwidth(none)) ///
           subtitle("Vintage", span size(3)) ///
           pos(11) ring(0) rows(1) ///
           keygap(0.5) colgap(0.1) size(2) ///
           symysize(0.85) symxsize(7) ///
           order(2 "1900-1925" 4 "1926-1950" 6 "1951-1975" 8 "1976-2000") ///
           stack) ///
    name(p_vintage, replace)

restore

* ==================================================================
* SECTION 4: Combine panels and export
* ==================================================================

gr combine p_time p_vintage, ///
    graphregion(color(white)) plotregion(fcolor(white)) ///
    rows(1) cols(2) ///
    name(combined, replace)

graph display combined, xsize(7)

graph export "${figures}/fig_1.pdf", as(pdf) replace

* ==================================================================
* End of script
* ==================================================================

di "Figure saved to: ${figures}/fig_1.pdf"
