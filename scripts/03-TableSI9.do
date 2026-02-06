* ==================================================================
* Table SI9: IV robustness checks
* ==================================================================
*
* Description: Tests robustness of IV estimates using alternative
*   instrument specifications:
*   - Leave-state-out instrument (garden_avg_leave)
*   - Controlling for long time periods (y50_year_gap)
*
* Columns:
*   (1) IV Leave-state-out: Distance only
*   (2) IV Leave-state-out: + Geography + metro FE
*   (3) IV with period FE: Distance only
*   (4) IV with period FE: + Geography + metro FE
*
* Outcomes:
*   - Log social isolation
*   - Time at home (sedentarism)
*   - GHG emissions (all trips)
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - table_iv_robustness_[outcome].tex
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

* Destring BUI 1900
destring mean_bui_1900, force replace

* Rename long variable names
rename sg_social_mean_home_dwelltime sg_social_homedwell

* ------------------------------------------------------------------
* 1.2 Create instruments
* ------------------------------------------------------------------

* Share of GCD neighborhoods in the US by year built
bysort first_year_built: egen garden_avg_us = mean(garden_metric_osm_d)

* Leave-state-out instrument
bysort first_year_built state_enc: egen garden_avg_state = mean(garden_metric_osm_d)
bysort first_year_built state_enc: egen garden_neigh_obs_state = count(garden_metric_osm_d)
bysort first_year_built: egen garden_neigh_obs_all = count(garden_metric_osm_d)

gen garden_avg_leave = (garden_neigh_obs_all * garden_avg_us - garden_avg_state * garden_neigh_obs_state) / (garden_neigh_obs_all - garden_neigh_obs_state)

* 50-year period bins for robustness
gen y50_year_gap = .
replace y50_year_gap = 1 if first_year_built <= 1870
replace y50_year_gap = 2 if first_year_built >= 1875 & first_year_built <= 1950
replace y50_year_gap = 3 if first_year_built >= 1955

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

* Treatment variable label
local ltit "High-GCD neighborhoods (Top 20\%)"

* ==================================================================
* SECTION 3: Run regressions for each outcome
* ==================================================================

foreach yvar in sg_log_interaction_norm sg_social_homedwell outcome_mob_GHG_all_trips {

    global depvar `yvar'

    * ------------------------------------------------------------------
    * 3.1 IV with Leave-State-Out Instrument
    * ------------------------------------------------------------------

    * Column 1: Distance only
    ivreghdfe $depvar (${gdi} = garden_avg_leave) ${dist} ///
        [aw=census2000blkgp_dem_total_pop], cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e1

    * Column 2: + Geography + metro FE
    ivreghdfe $depvar (${gdi} = garden_avg_leave) ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e2

    * ------------------------------------------------------------------
    * 3.2 IV Controlling for Long Time Periods
    * ------------------------------------------------------------------

    * Column 3: Distance + period FE
    ivreghdfe $depvar (${gdi} = garden_avg_us) ${dist} i.y50_year_gap ///
        [aw=census2000blkgp_dem_total_pop], cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e3

    * Column 4: + Geography + metro FE + period FE
    ivreghdfe $depvar (${gdi} = garden_avg_us) ${dist} ${geo_controls} i.y50_year_gap ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e4

    * ------------------------------------------------------------------
    * 3.3 Export table
    * ------------------------------------------------------------------

    estout e1 e2 e3 e4 using "${tables}/table_iv_robustness_${depvar}.tex", ///
        style(tex) ///
        varlabels(${gdi} "`ltit'") ///
        cells(b(star fmt(%9.3f)) se(par)) ///
        stats(N_full r2 widstat, fmt(%7.0f %7.2f %7.2f) ///
              labels("Observations" "R-squared" "F-Stat")) ///
        nolabel replace mlabels(none) collabels(none) ///
        starlevels(\$^{*}\$ .1 \$^{**}\$ .05 \$^{***}\$ .01) ///
        keep(${gdi}) ///
        order(${gdi})

    di "Table saved: table_iv_robustness_${depvar}.tex"

    estimates clear
}

* ==================================================================
* End of script
* ==================================================================

di _n "All IV robustness tables saved to: ${tables}"
