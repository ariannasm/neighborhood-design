* ==================================================================
* Table 2: Main results (OLS and IV)
* Table SI3: OLS and IV estimates using the continuous GCD measure
* Table SI4: PCA-based GCD robustness
* Table SI5: Top-tercile GCD robustness
* ==================================================================
*
* Description: Estimates the effect of Garden City Design (GCD) on:
*   - Greenhouse gas emissions
*   - Social isolation
*   - Time at home (sedentarism)
*
* Methods:
*   - OLS with distance controls
*   - OLS with geography controls and metro FE
*   - Propensity score (for binary GCD measures only)
*   - IV with national average GCD by vintage as instrument
*
* To produce different tables, change the $gdi global (line 53):
*   - garden_metric_osm_d     → Table 2 (main results, binary top 20%)
*   - garden_metric_osm       → Table SI3 (continuous measure)
*   - garden_metric_pca_d     → Table SI4 (PCA-based, binary top 20%)
*   - garden_metric_osm_top33 → Table SI5 (top tercile, binary top 33%)
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - table_[outcome]_[gdi]_us.tex
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
global tables "${replication_path}/tables"

* ------------------------------------------------------------------
* Settings: Choose GCD measure (MODIFY TO PRODUCE DIFFERENT TABLES)
* ------------------------------------------------------------------

* Options:
*   garden_metric_osm_d    → Table 2 (binary, top 20%)
*   garden_metric_osm      → Table SI3 (continuous)
*   garden_metric_pca_d    → Table SI4 (binary, PCA-based)
*   garden_metric_osm_top33 → Table SI5 (binary, top 33%)

* Default GCD measure (only used when running this script standalone)
* When called from Executer.do, this is overridden by the global set there
if "$gdi" == "" {
    global gdi garden_metric_osm_d
}

* ==================================================================
* SECTION 1: Load and prepare data
* ==================================================================

use "${data_clean}/us_data_matching.dta", clear

* ------------------------------------------------------------------
* 1.1 Create derived variables
* ------------------------------------------------------------------

* Distance bins (5 km intervals)
gen dist_bins = floor(dist_2000_city_altpop_km / 5) * 5

* Rename long variable names
rename sg_social_mean_home_dwelltime sg_social_homedwell

* Create instrument: national average GCD by construction year
bysort first_year_built: egen garden_avg_us = mean(${gdi})

* ------------------------------------------------------------------
* 1.2 Encode categorical variables
* ------------------------------------------------------------------

encode controlsgeo_county, gen(controlsgeo_county_enc)
encode controlsgeo_metro, gen(controlsgeo_metro_enc)

* ==================================================================
* SECTION 2: Define control variables and labels
* ==================================================================

* ------------------------------------------------------------------
* 2.1 Control variable sets
* ------------------------------------------------------------------

* Distance controls
global dist i.dist_bins

* Geographic controls (used in column 2 and 5)
global geo_controls i.state_enc ///
                    controlsgeo_avg_elev ///
                    controlsgeo_avg_slope ///
                    i.controlsgeo_ecozonesl1_enc ///
                    controlsgeo_neigh_longitude ///
                    controlsgeo_neigh_latitude

* Instrument
global instrument garden_avg_us

* ------------------------------------------------------------------
* 2.2 GCD measure labels
* ------------------------------------------------------------------

if "${gdi}" == "garden_metric_osm_d" {
    local ltit "High-GCD neighborhoods (Top 20\%)"
}
if "${gdi}" == "garden_metric_osm" {
    local ltit "GCD Index"
}
if "${gdi}" == "garden_metric_pca_d" {
    local ltit "High-GCD neighborhoods (Top 20\% PCA)"
}
if "${gdi}" == "garden_metric_osm_top33" {
    local ltit "High-GCD neighborhoods (Top 33\%)"
}

* ==================================================================
* SECTION 3: Run regressions for each outcome
* ==================================================================

foreach yvar in outcome_mob_GHG_all_trips sg_log_interaction_norm sg_social_homedwell {
    
    global depvar `yvar'
    
    * ------------------------------------------------------------------
    * 3.1 Define outcome labels
    * ------------------------------------------------------------------
    
    if "$depvar" == "outcome_mob_GHG_all_trips" {
        local depvarname "Annual greenhouse gas emissions"
    }
    if "$depvar" == "sg_social_homedwell" {
        local depvarname "Time at home"
    }
    if "$depvar" == "sg_log_interaction_norm" {
        local depvarname "Log social isolation"
    }
    
    * ------------------------------------------------------------------
    * 3.2 OLS Regressions
    * ------------------------------------------------------------------
    
    * Column 1: Distance controls only
    reg $depvar ${gdi} ${dist} [aw=census2000blkgp_dem_total_pop], ///
        cluster(controlsgeo_county)
    
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e1
    
    * Column 2: Geography controls + metro FE
    reghdfe $depvar ${gdi} ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e2
    
    * ------------------------------------------------------------------
    * 3.3 Propensity Score (binary GCD measures only)
    * ------------------------------------------------------------------
    
    if "${gdi}" != "garden_metric_osm" {
        teffects ipw ($depvar) ///
            (${gdi} ${dist} ${geo_controls}, probit), ///
            atet vce(cluster controlsgeo_county)
        
        estadd scalar N_full = e(N)
        estimates store e3
    }
    
    * ------------------------------------------------------------------
    * 3.4 IV Regressions
    * ------------------------------------------------------------------
    
    * Column 4: IV with distance controls only
    ivreghdfe $depvar (${gdi}=${instrument}) ${dist} ///
        [aw=census2000blkgp_dem_total_pop], ///
        cluster(controlsgeo_county)
    
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e4
    
    * Column 5: IV with geography controls + metro FE
    ivreghdfe $depvar (${gdi}=${instrument}) ${dist} ${geo_controls} ///
        [aw=census2000blkgp_dem_total_pop], ///
        absorb(controlsgeo_metro) cluster(controlsgeo_county)
    
    if e(N_full) == . {
        estadd scalar N_full = e(N)
    }
    estimates store e5
    
    * ------------------------------------------------------------------
    * 3.5 Export table
    * ------------------------------------------------------------------
    
    if "${gdi}" != "garden_metric_osm" {
        * Binary GCD: 5 columns (including propensity score)
        estout e1 e2 e3 e4 e5 using "${tables}/table_${depvar}_${gdi}_us.tex", ///
            style(tex) ///
            rename("r1vs0.${gdi}" "${gdi}") ///
            varlabels(${gdi} "`ltit'") ///
            cells(b(star fmt(%9.3f)) se(par)) ///
            stats(N_full r2 widstat, ///
                  fmt(%7.0f %7.2f %7.2f) ///
                  labels("Observations" "Clusters" "R-squared" "F-Stat")) ///
            nolabel replace mlabels(none) collabels(none) ///
            starlevels(\$^{*}\$ .1 \$^{**}\$ .05 \$^{***}\$ .01) ///
            keep(${gdi}) ///
            order(${gdi})
    }
    else {
        * Continuous GCD: 4 columns (skip propensity score)
        estout e1 e2 e4 e5 using "${tables}/table_${depvar}_${gdi}_us.tex", ///
            style(tex) ///
            rename("r1vs0.${gdi}" "${gdi}") ///
            varlabels(${gdi} "`ltit'") ///
            cells(b(star fmt(%9.3f)) se(par)) ///
            stats(N_full r2 widstat, ///
                  fmt(%7.0f %7.2f %7.2f) ///
                  labels("Observations" "R-squared" "F-Stat")) ///
            nolabel replace mlabels(none) collabels(none) ///
            starlevels(\$^{*}\$ .1 \$^{**}\$ .05 \$^{***}\$ .01) ///
            keep(${gdi}) ///
            order(${gdi})
    }
    
    di "Table saved: table_${depvar}_${gdi}_us.tex"
    
    * Clear stored estimates
    estimates clear
}

* ==================================================================
* End of script
* ==================================================================

di _n "All tables saved to: ${tables}"
di "GCD measure used: ${gdi}"
