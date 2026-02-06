* ==================================================================
* Table SI12: Census tract-level analysis
* ==================================================================
*
* Description: Tests robustness by aggregating data to the Census
*   tract level (from block group level) and re-running main
*   specifications.
*
* Columns:
*   (1) OLS: Distance only
*   (2) OLS: + Geography + metro FE
*   (3) IPW: Geography controls
*   (4) IV: Distance only
*   (5) IV: + Geography + metro FE
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
*   - table_tract_level_[outcome].tex
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

* Rename long variable names
rename sg_social_mean_home_dwelltime sg_social_homedwell

* ------------------------------------------------------------------
* 1.1 Aggregate to tract level
* ------------------------------------------------------------------

* Extract tract ID from block group identifier
gen cbg_id = regexs(1) if regexm(ft_blc_state, "^(G[0-9]+)")
gen tract_id = substr(cbg_id, 2, 11)

* Collapse to tract level (population-weighted)
collapse (firstnm) controlsgeo_county controlsgeo_metro state_enc ///
         controlsgeo_ecozonesl1_enc region_name ///
         (mean) sg_log_interaction_norm sg_social_homedwell ///
         outcome_mob_GHG_all_trips garden_metric_osm ///
         controlsgeo_avg_elev controlsgeo_avg_slope ///
         controlsgeo_neigh_longitude controlsgeo_neigh_latitude ///
         dist_2000_city_altpop_km ///
         (median) first_year_built ///
         (rawsum) census2000tract_dem_total_pop = census2000blkgp_dem_total_pop ///
         [w=census2000blkgp_dem_total_pop], by(tract_id)

* ------------------------------------------------------------------
* 1.2 Create derived variables at tract level
* ------------------------------------------------------------------

* Create GCD quintiles and dummy at tract level
xtile garden_metric_osm_quint = garden_metric_osm, n(5)
gen garden_metric_osm_d = (garden_metric_osm_quint == 5)

* Distance bins (5 km intervals)
gen dist_bins = floor(dist_2000_city_altpop_km / 5) * 5

* ------------------------------------------------------------------
* 1.3 Create instrument at tract level
* ------------------------------------------------------------------

* Share of GCD neighborhoods in the US by year built
bysort first_year_built: egen garden_avg_us = mean(garden_metric_osm_d)

* ------------------------------------------------------------------
* 1.4 Encode categorical variables
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

foreach yvar in sg_log_interaction_norm sg_social_homedwell outcome_mob_GHG_all_trips {

    global depvar `yvar'

    * ------------------------------------------------------------------
    * 3.1 OLS Regressions
    * ------------------------------------------------------------------

    * Column 1: Distance only
    reg $depvar ${gdi} ${dist} ///
        [aw=census2000tract_dem_total_pop], cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e1

    * Column 2: + Geography + metro FE
    reghdfe $depvar ${gdi} ${dist} ${geo_controls} ///
        [aw=census2000tract_dem_total_pop], ///
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
    * 3.3 IV Regressions
    * ------------------------------------------------------------------

    * Column 4: Distance only
    ivreghdfe $depvar (${gdi} = ${instrument_list}) ${dist} ///
        [aw=census2000tract_dem_total_pop], cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e4

    * Column 5: + Geography + metro FE
    ivreghdfe $depvar (${gdi} = ${instrument_list}) ${dist} ${geo_controls} ///
        [aw=census2000tract_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e5

    * ------------------------------------------------------------------
    * 3.4 Export table
    * ------------------------------------------------------------------

    estout e1 e2 e3 e4 e5 using "${tables}/table_tract_level_${depvar}.tex", ///
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

    di "Table saved: table_tract_level_${depvar}.tex"

    estimates clear
}

* ==================================================================
* End of script
* ==================================================================

di _n "All tract-level robustness tables saved to: ${tables}"
