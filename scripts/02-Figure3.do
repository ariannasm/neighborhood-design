* ==================================================================
* Figure 3: Outcomes by distance to city center
* ==================================================================
*
* Description: Creates panel figure showing outcomes by distance
*   for High GCD, Mean, and Low GCD neighborhoods:
*   A) Log social isolation
*   B) Daily time at home
*   C) Annual GHG per person
*
* Method: Rolling IV regression within +/- 10 km windows,
*   using national average GCD by vintage as instrument
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - fig_3.pdf
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
global orange_light_op ""231 151 80%20""
global orange_dark ""243 102 40""
global orange_dark_op ""243 102 40%30""

global blue_light ""87 158 190""
global blue_light_med ""74 114 173""
global blue_light_med_op ""74 114 173%20""
global blue_med ""69 80 141""
global blue_med_op ""69 80 141%20""
global blue_dark ""51 48 99""
global blue_dark_op ""51 48 99%20""

* ------------------------------------------------------------------
* Set graph fonts
* ------------------------------------------------------------------

graph set window fontface "Helvetica"
graph set ps fontface "Helvetica"

* ==================================================================
* SECTION 1: Load and prepare data
* ==================================================================

use "${data_clean}/us_data_matching.dta", clear

* ------------------------------------------------------------------
* 1.1 Create derived variables
* ------------------------------------------------------------------

* Rename long variable name
rename sg_social_mean_home_dwelltime sg_social_homedwell

* Create 1 km distance bins
gen bins = floor(dist_2000_city_altpop_km / 1) * 1

* Restrict sample to within 40 km of city center
keep if dist_2000_city_altpop_km <= 40

* Create instrument: national average GCD by construction year
bysort first_year_built: egen garden_avg_us = mean(garden_metric_osm_d)

* ------------------------------------------------------------------
* 1.2 Encode categorical variables
* ------------------------------------------------------------------

encode controlsgeo_metro, gen(controlsgeo_metro_enc)

* ==================================================================
* SECTION 2: Save population by distance bin (for weighting)
* ==================================================================

preserve

collapse (sum) census2000blkgp_dem_total_pop, by(bins)
sort bins

tempfile pop
save `pop'

restore

* ==================================================================
* SECTION 3: Create frame to store results
* ==================================================================

frame create results

* ==================================================================
* SECTION 4: Run rolling IV regressions for each outcome
* ==================================================================

* Define control variables
global geo_controls i.state_enc ///
                    controlsgeo_avg_elev ///
                    controlsgeo_avg_slope ///
                    i.controlsgeo_ecozonesl1_enc ///
                    controlsgeo_neigh_longitude ///
                    controlsgeo_neigh_latitude

* Instrument
global instrument garden_avg_us

* Panel letters
local letters "A B C"

* Loop over outcomes
foreach yvar in sg_log_interaction_norm sg_social_homedwell outcome_mob_GHG_all_trips {

    global depvar `yvar'
    
    * Extract panel letter
    local thisLetter = word("`letters'", 1)
    local letters : list letters - thisLetter
    
    * ------------------------------------------------------------------
    * 4.1 Define outcome labels and y-axis ranges
    * ------------------------------------------------------------------
    
    if "$depvar" == "sg_log_interaction_norm" {
        local depvarname "Log social isolation"
        local start = 2.5
        local end   = 4
        local skip  = 0.5
    }
    if "$depvar" == "sg_social_homedwell" {
        local depvarname "Daily time at home"
        local start = 550
        local end   = 750
        local skip  = 50
    }
    if "$depvar" == "outcome_mob_GHG_all_trips" {
        local depvarname "Annual GHG per person"
        local start = 1.4
        local end   = 2.8
        local skip  = 0.4
    }
    
    * ------------------------------------------------------------------
    * 4.2 Initialize results frame
    * ------------------------------------------------------------------
    
    frame results {
        clear
        set obs 40
        gen mean_var = .
        gen mean_high = .
        gen mean_low = .
        gen bins = _n - 1
    }
    
    * ------------------------------------------------------------------
    * 4.3 Run IV regression for each distance bin
    * ------------------------------------------------------------------
    
    forvalues bin = 0(1)39 {
        
        * IV regression within +/- 10 km window
        ivreghdfe $depvar (garden_metric_osm_d=${instrument}) ${geo_controls} ///
            if bins >= `bin' - 10 & bins <= `bin' + 10 ///
            [aw=census2000blkgp_dem_total_pop], ///
            absorb(controlsgeo_metro) cluster(controlsgeo_county)
        
        * Get average outcome at this bin
        sum $depvar if bins == `bin' [aw=census2000blkgp_dem_total_pop]
        local avg_neigh = r(mean)
        
        * Get average GCD at this bin
        sum garden_metric_osm_d if bins == `bin' [aw=census2000blkgp_dem_total_pop]
        local avg_gdi = r(mean)
        
        * Store results: compute counterfactual high/low GCD outcomes
        frame results {
            replace mean_var = `avg_neigh' if bins == `bin'
            replace mean_high = `avg_neigh' + _b[garden_metric_osm_d] * (1 - `avg_gdi') if bins == `bin'
            replace mean_low = `avg_neigh' - _b[garden_metric_osm_d] * `avg_gdi' if bins == `bin'
        }
    }
    
    * ------------------------------------------------------------------
    * 4.4 Create figure in results frame
    * ------------------------------------------------------------------
    
    frame results {
        
        * Smooth results with rolling mean (+/- 2 bins)
        rangestat (mean) mean_high mean_var mean_low, interval(bins -2 2)
        
        * Merge population weights
        merge 1:1 bins using `pop', nogenerate
        sort bins
        
        * Create figure
        twoway (connected mean_high_mean bins, color(${blue_dark}) msymbol(circle) msize(small)) ///
               (connected mean_var_mean bins, color(${orange_dark}) msymbol(circle) msize(small)) ///
               (connected mean_low_mean bins, color(${blue_med}) msymbol(circle) msize(small)), ///
            ytitle("`depvarname'", size(7)) ///
            xtitle("Distance to main city (km)", size(7)) ///
            ylabel(`start'(`skip')`end', labsize(large) tlcolor("black") glcolor("145 168 208")) ///
            xlabel(, labsize(large) tlcolor("black") glcolor("145 168 208")) ///
            yscale(lstyle(none)) ///
            xscale(lstyle(none)) ///
            legend(nobox) ///
            xsize(5) ysize(5) scale(1) ///
            legend(order(1 "High GCD" 2 "Mean" 3 "Low GCD") ///
                   ring(0) position(5) rows(3) ///
                   region(lc(none)) keygap(*.5) rowgap(*.1) size(medium)) ///
            graphregion(color(white)) bgcolor(white) ///
            plotregion(lcolor(black) lwidth(thin)) ///
            title("{bf:`thisLetter'}", justification(left) position(11) size(6) span) ///
            name(p1$depvar, replace)
    }
}

* ==================================================================
* SECTION 5: Combine panels and export
* ==================================================================

gr combine p1sg_log_interaction_norm p1sg_social_homedwell p1outcome_mob_GHG_all_trips, ///
    graphregion(color(white)) plotregion(fcolor(white)) ///
    rows(1) cols(3) ///
    name(combined, replace)

graph display combined, xsize(12)

graph export "${figures}/fig_3.pdf", as(pdf) replace

* ==================================================================
* End of script
* ==================================================================

di _n "Figure saved to: ${figures}/fig_3.pdf"
