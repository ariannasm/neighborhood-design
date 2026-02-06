* ==================================================================
* Table SI1: Complementary outcomes
* ==================================================================
*
* Description: Estimates the effect of Garden City Design (GCD) on
*   mechanism outcomes using three estimation strategies:
*   - OLS with distance controls
*   - OLS with geography controls + metro FE
*   - Inverse Probability Weighting (IPW)
*   - IV with distance controls
*   - IV with geography controls + metro FE
*
* Outcomes:
*   - Walk index
*   - Log POI density
*   - GHG emissions (commute)
*   - GHG emissions (non-commute)
*   - Percent auto ownership 2+
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - table_mechanisms_[outcome].tex
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

* Log POI
gen log_outcome_poi_total_norm = log(outcome_poi_total_norm)

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
* SECTION 2: Define control variables and estimation settings
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

* Instrument: National GCD share by year built
global instrument_list garden_avg_us

* Treatment variable label
local ltit "High-GCD neighborhoods (Top 20\%)"

* ==================================================================
* SECTION 3: Run regressions for each outcome
* ==================================================================

foreach yvar in outcome_walk_index log_outcome_poi_total_norm outcome_mob_GHG_commute outcome_mob_GHG_noncommute outcome_mob_Pct_AO2p {

    global depvar `yvar'

    * ------------------------------------------------------------------
    * 3.1 OLS Regressions
    * ------------------------------------------------------------------

    * Column 1: Distance controls only
    reghdfe $depvar ${gdi} ${dist} ///
        [aw=census2000blkgp_dem_total_pop], cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e1

    * Column 2: + Geography controls + metro FE
    reghdfe $depvar ${gdi} ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e2

    * ------------------------------------------------------------------
    * 3.2 Inverse Probability Weighting (IPW)
    * ------------------------------------------------------------------

    * Column 3: IPW with geography controls
    teffects ipw ($depvar) (${gdi} ${dist} ${geo_controls}, probit), ///
        atet vce(cluster controlsgeo_county)
    estadd scalar N_full = e(N)
    estimates store e3

    * ------------------------------------------------------------------
    * 3.3 Instrumental Variables
    * ------------------------------------------------------------------

    * Column 4: IV with distance controls only
    ivreghdfe $depvar (${gdi} = ${instrument_list}) ${dist} ///
        [aw=census2000blkgp_dem_total_pop], cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e4

    * Column 5: IV + Geography controls + metro FE
    ivreghdfe $depvar (${gdi} = ${instrument_list}) ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e5

    * ------------------------------------------------------------------
    * 3.4 Export table
    * ------------------------------------------------------------------

    estout e1 e2 e3 e4 e5 using "${tables}/table_mechanisms_${depvar}.tex", ///
        style(tex) ///
        rename("r1vs0.${gdi}" "${gdi}") ///
        varlabels(${gdi} "`ltit'") ///
        cells(b(star fmt(%9.3f)) se(par)) ///
        stats(N_full r2 widstat, fmt(%7.0f %7.2f %7.2f) ///
              labels("Observations" "R-squared" "F-Stat")) ///
        nolabel replace mlabels(none) collabels(none) ///
        starlevels(\$^{*}\$ .1 \$^{**}\$ .05 \$^{***}\$ .01) ///
        keep(${gdi}) ///
        order(${gdi})

    di "Table saved: table_mechanisms_${depvar}.tex"

    * Clear stored estimates
    estimates clear
}

* ==================================================================
* End of script
* ==================================================================

di _n "All mechanism tables saved to: ${tables}"
