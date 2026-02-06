* ==================================================================
* Table SI2: OLS estimates with demographic and historical controls
* ==================================================================
*
* Description: Estimates the effect of Garden City Design (GCD) on:
*   - Log social isolation
*   - Time at home (sedentarism)
*   - Annual greenhouse gas emissions
*
* Columns show progressively more controls:
*   (1) Distance controls only
*   (2) + Geography controls + metro FE
*   (3) + Historical building density (BUI 1900)
*   (4) + Demographic controls
*   (5) + Population density
*   (6) + Work from home share
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - table_[outcome]_ols_SI2.tex
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
gen log_census2000_blckgrp_pop_dens = log(census2000blkgp_dem_total_pop / controlsplan_areaneigh_km)

* Log income
gen log_census2000blkgp_income_pc = log(census2000blkgp_income_pc)

* Destring BUI 1900
destring mean_bui_1900, force replace

* Rename long variable names
rename sg_social_mean_home_dwelltime sg_social_homedwell

* ------------------------------------------------------------------
* 1.2 Encode categorical variables
* ------------------------------------------------------------------

encode controlsgeo_county, gen(controlsgeo_county_enc)
encode controlsgeo_metro, gen(controlsgeo_metro_enc)

* ==================================================================
* SECTION 2: Define control variables
* ==================================================================

* Distance controls
global dist i.dist_bins

* Geographic controls
global geo_controls i.state_enc ///
                    controlsgeo_avg_elev ///
                    controlsgeo_avg_slope ///
                    i.controlsgeo_ecozonesl1_enc ///
                    controlsgeo_neigh_longitude ///
                    controlsgeo_neigh_latitude

* Demographic controls
global demo_controls census2000blkgp_dem_SH_white ///
                     census2000blkgp_fam_SH_married ///
                     census2000blkgp_dem_SH_somecoll ///
                     census2000blkgp_dem_MED_age ///
                     log_census2000blkgp_income_pc

* Treatment variable label
local ltit "High-GCD neighborhoods (Top 20\%)"

* ==================================================================
* SECTION 3: Run regressions for each outcome
* ==================================================================

foreach yvar in sg_log_interaction_norm sg_social_homedwell outcome_mob_GHG_all_trips {

    global depvar `yvar'

    * ------------------------------------------------------------------
    * 3.1 OLS Regressions
    * ------------------------------------------------------------------

    * Column 1: Distance controls only
    reg $depvar garden_metric_osm_d ${dist} ///
        [aw=census2000blkgp_dem_total_pop], cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e1

    * Column 2: + Geography controls + metro FE
    reghdfe $depvar garden_metric_osm_d ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e2

    * Column 3: + Historical building density (BUI 1900)
    reghdfe $depvar garden_metric_osm_d ${dist} ${geo_controls} ///
        mean_bui_1900 ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e3

    * Column 4: + Demographic controls
    reghdfe $depvar garden_metric_osm_d ${dist} ${geo_controls} ///
        mean_bui_1900 ${demo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e4

    * Column 5: + Population density
    reghdfe $depvar garden_metric_osm_d ${dist} ${geo_controls} ///
        mean_bui_1900 log_census2000_blckgrp_pop_dens ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e5

    * Column 6: + Work from home share
    reghdfe $depvar garden_metric_osm_d ${dist} ${geo_controls} ///
        mean_bui_1900 log_census2000_blckgrp_pop_dens wfh_share ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e6

    * ------------------------------------------------------------------
    * 3.2 Export table
    * ------------------------------------------------------------------

    estout e1 e2 e3 e4 e5 e6 using "${tables}/table_${depvar}_ols_SI2.tex", ///
        style(tex) ///
        varlabels(garden_metric_osm_d "`ltit'") ///
        cells(b(star fmt(%9.3f)) se(par)) ///
        stats(N_full N_clust r2, fmt(%7.0f %7.0f %7.2f) ///
              labels("Observations" "Clusters" "R-squared")) ///
        nolabel replace mlabels(none) collabels(none) ///
        starlevels(\$^{*}\$ .1 \$^{**}\$ .05 \$^{***}\$ .01) ///
        keep(garden_metric_osm_d) ///
        order(garden_metric_osm_d)

    di "Table saved: table_${depvar}_ols_SI2.tex"

    * Clear stored estimates
    estimates clear
}

* ==================================================================
* End of script
* ==================================================================

di _n "All OLS robustness tables saved to: ${tables}"
