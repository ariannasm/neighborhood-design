* ==================================================================
* Table SI10: Controlling for neighborhood age effects
* ==================================================================
*
* Description: Tests robustness by adjusting outcomes for neighborhood
*   age effects estimated from pre-1870 neighborhoods, then re-running
*   OLS and IV specifications on age-adjusted outcomes.
*
* Columns:
*   (1) Age effect estimation (pre-1870, metro FE)
*   (2) Age effect estimation (pre-1870, + geography)
*   (3) IV on age-adjusted outcome (metro FE)
*   (4) IV on age-adjusted outcome (+ geography)
*   (5) OLS on age-adjusted outcome (metro FE)
*   (6) OLS on age-adjusted outcome (+ geography)
*
* Outcomes:
*   - Log social isolation
*   - GHG emissions (all trips)
*   - Time at home (sedentarism)
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - table_age_robustness_[outcome].tex
*
* ==================================================================

clear all
set more off

* ------------------------------------------------------------------
* Setup: Define paths (MODIFY THIS PATH FOR YOUR SYSTEM)
* ------------------------------------------------------------------

* UPDATE THIS PATH to your local Replication folder
global replication_path "/path/to/Replication"

global data_clean "${replication_path}/data/clean"
global tables "${replication_path}/tables"

* ==================================================================
* SECTION 1: Load and prepare data
* ==================================================================

use "${data_clean}/us_data_matching.dta", clear

* ------------------------------------------------------------------
* 1.1 Create derived variables
* ------------------------------------------------------------------

* Distance bins (5 km intervals)
gen dist_bins = floor(dist_2000_city_altpop_km / 5) * 5

* Population density
gen controlsplan_areaneigh_km = controlsplan_areaneigh_mts / 1000000

* Neighborhood age
gen neigh_age = 2020 - first_year_built

* Destring BUI 1900
destring mean_bui_1900, force replace

* Rename long variable names
rename sg_social_mean_home_dwelltime sg_social_homedwell

* ------------------------------------------------------------------
* 1.2 Create instrument
* ------------------------------------------------------------------

* Share of GCD neighborhoods in the US by year built
bysort first_year_built: egen garden_avg_us = mean(garden_metric_osm_d)

* ------------------------------------------------------------------
* 1.3 Encode categorical variables
* ------------------------------------------------------------------

encode controlsgeo_county, gen(controlsgeo_county_enc)
encode controlsgeo_metro, gen(controlsgeo_metro_enc)

* ==================================================================
* SECTION 2: Define control variables
* ==================================================================

* Treatment variable
global gdi garden_metric_osm_d

* Distance controls
global dist i.dist_bins

* Geographic controls
global geo_controls i.state_enc ///
                    controlsgeo_avg_elev ///
                    controlsgeo_avg_slope ///
                    i.controlsgeo_ecozonesl1_enc ///
                    controlsgeo_neigh_longitude ///
                    controlsgeo_neigh_latitude

* Instrument
global instrument_list garden_avg_us

* Treatment variable label
local ltit "High-GCD neighborhoods (Top 20\%)"

* ==================================================================
* SECTION 3: Run regressions for each outcome
* ==================================================================

foreach yvar in sg_log_interaction_norm outcome_mob_GHG_all_trips sg_social_homedwell {

    global depvar `yvar'

    * Clean up from previous iteration
    cap drop y_net_of_age
    cap drop y_net_of_age_demo

    * ------------------------------------------------------------------
    * 3.1 Estimate Age Effects (pre-1870 sample)
    * ------------------------------------------------------------------

    * Column 1: Age effect with metro FE only
    reghdfe $depvar neigh_age ${dist} if first_year_built <= 1870 ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e1

    * Create age-adjusted outcome (metro FE specification)
    gen y_net_of_age = $depvar - neigh_age * _b[neigh_age]

    * Column 2: Age effect with geography controls
    reghdfe $depvar neigh_age ${dist} ${geo_controls} if first_year_built <= 1870 ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e2

    * Create age-adjusted outcome (geography specification)
    gen y_net_of_age_demo = $depvar - neigh_age * _b[neigh_age]

    * ------------------------------------------------------------------
    * 3.2 IV on Age-Adjusted Outcomes
    * ------------------------------------------------------------------

    * Column 3: IV on age-adjusted outcome (metro FE)
    ivreghdfe y_net_of_age (${gdi} = ${instrument_list}) ${dist} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e3

    * Column 4: IV on age-adjusted outcome (+ geography)
    ivreghdfe y_net_of_age_demo (${gdi} = ${instrument_list}) ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e4

    * ------------------------------------------------------------------
    * 3.3 OLS on Age-Adjusted Outcomes
    * ------------------------------------------------------------------

    * Column 5: OLS on age-adjusted outcome (metro FE)
    reghdfe y_net_of_age ${gdi} ${dist} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e5

    * Column 6: OLS on age-adjusted outcome (+ geography)
    reghdfe y_net_of_age_demo ${gdi} ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e6

    * ------------------------------------------------------------------
    * 3.4 Export table
    * ------------------------------------------------------------------

    estout e1 e2 e3 e4 e5 e6 using "${tables}/table_age_robustness_${depvar}.tex", ///
        style(tex) ///
        varlabels(${gdi} "`ltit'" neigh_age "Age Effect") ///
        cells(b(star fmt(%9.3f)) se(par)) ///
        stats(N_full r2 widstat, fmt(%7.0f %7.2f %7.2f) ///
              labels("Observations" "R-squared" "F-Stat")) ///
        nolabel replace mlabels(none) collabels(none) ///
        starlevels(\$^{*}\$ .1 \$^{**}\$ .05 \$^{***}\$ .01) ///
        keep(${gdi} neigh_age) ///
        order(neigh_age ${gdi})

    di "Table saved: table_age_robustness_${depvar}.tex"

    estimates clear
}

* ==================================================================
* End of script
* ==================================================================

di _n "All age robustness tables saved to: ${tables}"
