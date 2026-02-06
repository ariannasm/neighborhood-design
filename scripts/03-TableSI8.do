* ==================================================================
* Table SI8: Controlling for residential zoning
* ==================================================================
*
* Description: Tests robustness of GCD effects to controlling for
*   the share of plots zoned residential. Estimates OLS and IV
*   specifications with and without zoning controls.
*
* Columns:
*   (1) OLS: Baseline (geography + metro FE)
*   (2) OLS: + Share residential zoning
*   (3) IV: Baseline (geography + metro FE)
*   (4) IV: + Share residential zoning
*
* Outcomes:
*   - Log social interaction
*   - Time at home (sedentarism)
*   - GHG emissions (all trips)
*   - Share of plots zoned residential (as outcome)
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - table_zoning_[outcome].tex
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

foreach yvar in sg_log_interaction_norm sg_social_homedwell outcome_mob_GHG_all_trips outcome_parcel_res_comb {

    global depvar `yvar'

    * ------------------------------------------------------------------
    * 3.1 OLS Regressions
    * ------------------------------------------------------------------

    * Column 1: Baseline (geography + metro FE)
    reghdfe $depvar ${gdi} ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e1

    * Column 2: + Share residential zoning
    reghdfe $depvar ${gdi} ${dist} ${geo_controls} outcome_parcel_res_comb ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e2

    * ------------------------------------------------------------------
    * 3.2 IV Regressions
    * ------------------------------------------------------------------

    * Column 3: IV Baseline (geography + metro FE)
    ivreghdfe $depvar (${gdi} = ${instrument_list}) ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e3

    * Column 4: IV + Share residential zoning
    ivreghdfe $depvar (${gdi} = ${instrument_list}) ${dist} ${geo_controls} ///
        outcome_parcel_res_comb ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e4

    * ------------------------------------------------------------------
    * 3.3 Export table
    * ------------------------------------------------------------------

    estout e1 e2 e3 e4 using "${tables}/table_zoning_${depvar}.tex", ///
        style(tex) ///
        varlabels(${gdi} "`ltit'" outcome_parcel_res_comb "Share of Plots Zoned Residential") ///
        cells(b(star fmt(%9.3f)) se(par)) ///
        stats(N_full r2 widstat, fmt(%7.0f %7.2f %7.2f) ///
              labels("Observations" "R-squared" "F-Stat")) ///
        nolabel replace mlabels(none) collabels(none) ///
        starlevels(\$^{*}\$ .1 \$^{**}\$ .05 \$^{***}\$ .01) ///
        keep(${gdi} outcome_parcel_res_comb) ///
        order(${gdi} outcome_parcel_res_comb)

    di "Table saved: table_zoning_${depvar}.tex"

    estimates clear
}

* ==================================================================
* End of script
* ==================================================================

di _n "All zoning robustness tables saved to: ${tables}"
