* ==================================================================
* Table SI7: Variance decomposition of GCD
* ==================================================================
*
* Description: Decomposes the explanatory power of different factors
*   on the Garden City Design (GCD) index:
*   - Neighborhood vintage (year built)
*   - Distance to city center
*   - Metro and state fixed effects
*   - Geography (elevation, slope, ecozones, coordinates)
*
* Columns:
*   (1) Vintage + Distance only
*   (2) + Geography + Metro/State FE
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - table_variance_[depvar].tex
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

* Create dummy variables for variance decomposition
tab dist_bins, gen(d_dist_bins)
tab first_year_built, gen(d_first_year_built)
tab controlsgeo_ecozonesl1_enc, gen(d_controlsgeo_ecozones)

* Destring BUI 1900
destring mean_bui_1900, force replace

* ------------------------------------------------------------------
* 1.2 Encode categorical variables
* ------------------------------------------------------------------

encode controlsgeo_county, gen(controlsgeo_county_enc)
encode controlsgeo_metro, gen(controlsgeo_metro_enc)

* ==================================================================
* SECTION 2: Run variance decomposition for each outcome
* ==================================================================

foreach yvar in garden_metric_osm_d garden_metric_osm {

    global depvar `yvar'

    * Set label for output
    if "$depvar" == "garden_metric_osm_d" {
        local ltit "Top 20\% Garden Design Index"
    }
    if "$depvar" == "garden_metric_osm" {
        local ltit "Average Garden Design Index"
    }

    * ------------------------------------------------------------------
    * Column 1: Vintage + Distance only
    * ------------------------------------------------------------------

    reg $depvar d_first_year_built2-d_first_year_built42 d_dist_bins2-d_dist_bins47, ///
        cluster(controlsgeo_county)
    estimates store e1

    * Decompose variance attributed to vintages
    quietly: corr $depvar d_first_year_built2-d_first_year_built42 if e(sample) == 1, cov
    matrix vmatrix = r(C)

    local r2_vint = 0
    forvalues j = 2(1)42 {
        local r2_vint = `r2_vint' + _b[d_first_year_built`j'] * vmatrix[`j',1] / vmatrix[1,1]
    }
    estadd scalar r2_vint = `r2_vint'

    * F-stat for vintages
    quietly: test d_first_year_built2 d_first_year_built3 d_first_year_built4 ///
        d_first_year_built5 d_first_year_built6 d_first_year_built7 d_first_year_built8 ///
        d_first_year_built9 d_first_year_built10 d_first_year_built11 d_first_year_built12 ///
        d_first_year_built13 d_first_year_built14 d_first_year_built15 d_first_year_built16 ///
        d_first_year_built17 d_first_year_built18 d_first_year_built19 d_first_year_built20 ///
        d_first_year_built21 d_first_year_built22 d_first_year_built23 d_first_year_built24 ///
        d_first_year_built25 d_first_year_built26 d_first_year_built27 d_first_year_built28 ///
        d_first_year_built29 d_first_year_built30 d_first_year_built31 d_first_year_built32 ///
        d_first_year_built33 d_first_year_built34 d_first_year_built35 d_first_year_built36 ///
        d_first_year_built37 d_first_year_built38 d_first_year_built39 d_first_year_built40 ///
        d_first_year_built41 d_first_year_built42
    estadd scalar fstat = `r(F)'

    * Decompose variance attributed to distance bins
    quietly: corr $depvar d_dist_bins2-d_dist_bins47, cov
    matrix vmatrix = r(C)

    local r2_dist_col1 = 0
    forvalues j = 2(1)47 {
        local r2_dist_col1 = `r2_dist_col1' + _b[d_dist_bins`j'] * vmatrix[`j',1] / vmatrix[1,1]
    }
    estadd scalar r2_dist = `r2_dist_col1'

    * All local determinants for column 1 = distance only
    estadd scalar r2_local = `r2_dist_col1'

    * ------------------------------------------------------------------
    * Column 2: + Geography + Metro/State FE
    * ------------------------------------------------------------------

    reg $depvar d_first_year_built2-d_first_year_built42 d_dist_bins2-d_dist_bins47 ///
        i.controlsgeo_metro_enc i.state_enc ///
        controlsgeo_avg_elev controlsgeo_avg_slope ///
        d_controlsgeo_ecozones2-d_controlsgeo_ecozones11 ///
        controlsgeo_neigh_longitude controlsgeo_neigh_latitude, ///
        cluster(controlsgeo_county)
    estimates store e2

    local r2_total = e(r2)

    * Decompose variance attributed to vintages
    quietly: corr $depvar d_first_year_built2-d_first_year_built42 if e(sample) == 1, cov
    matrix vmatrix = r(C)

    local r2_vint = 0
    forvalues j = 2(1)42 {
        local r2_vint = `r2_vint' + _b[d_first_year_built`j'] * vmatrix[`j',1] / vmatrix[1,1]
    }
    estadd scalar r2_vint = `r2_vint'

    * F-stat for vintages
    quietly: test d_first_year_built2 d_first_year_built3 d_first_year_built4 ///
        d_first_year_built5 d_first_year_built6 d_first_year_built7 d_first_year_built8 ///
        d_first_year_built9 d_first_year_built10 d_first_year_built11 d_first_year_built12 ///
        d_first_year_built13 d_first_year_built14 d_first_year_built15 d_first_year_built16 ///
        d_first_year_built17 d_first_year_built18 d_first_year_built19 d_first_year_built20 ///
        d_first_year_built21 d_first_year_built22 d_first_year_built23 d_first_year_built24 ///
        d_first_year_built25 d_first_year_built26 d_first_year_built27 d_first_year_built28 ///
        d_first_year_built29 d_first_year_built30 d_first_year_built31 d_first_year_built32 ///
        d_first_year_built33 d_first_year_built34 d_first_year_built35 d_first_year_built36 ///
        d_first_year_built37 d_first_year_built38 d_first_year_built39 d_first_year_built40 ///
        d_first_year_built41 d_first_year_built42
    estadd scalar fstat = `r(F)'

    * Decompose variance attributed to distance bins
    quietly: corr $depvar d_dist_bins2-d_dist_bins47, cov
    matrix vmatrix = r(C)

    local r2_dist = 0
    forvalues j = 2(1)47 {
        local r2_dist = `r2_dist' + _b[d_dist_bins`j'] * vmatrix[`j',1] / vmatrix[1,1]
    }
    estadd scalar r2_dist = `r2_dist'

    * Decompose variance attributed to geography
    corr $depvar controlsgeo_avg_elev controlsgeo_avg_slope ///
        controlsgeo_neigh_longitude controlsgeo_neigh_latitude, cov
    matrix vmatrix = r(C)

    local r2_geo = (_b[controlsgeo_avg_elev] * vmatrix[2,1] ///
                    + _b[controlsgeo_avg_slope] * vmatrix[3,1] ///
                    + _b[controlsgeo_neigh_longitude] * vmatrix[4,1] ///
                    + _b[controlsgeo_neigh_latitude] * vmatrix[5,1]) / vmatrix[1,1]

    corr $depvar d_controlsgeo_ecozones2-d_controlsgeo_ecozones11, cov
    matrix vmatrix = r(C)

    forvalues j = 2(1)11 {
        local r2_geo = `r2_geo' + _b[d_controlsgeo_ecozones`j'] * vmatrix[`j',1] / vmatrix[1,1]
    }
    estadd scalar r2_geo = `r2_geo'

    * Variance attributed to metro FE (computed as residual)
    local r2_metro = `r2_total' - `r2_dist' - `r2_vint' - `r2_geo'
    estadd scalar r2_metro = `r2_metro'

    * All local determinants for column 2 = distance + geography + metro/state FE
    local r2_local = `r2_dist' + `r2_geo' + `r2_metro'
    estadd scalar r2_local = `r2_local'

    * ------------------------------------------------------------------
    * Export table
    * ------------------------------------------------------------------

    estout e1 e2 using "${tables}/table_variance_${depvar}.tex", ///
        style(tex) ///
        varlabels($depvar "`ltit'") ///
        cells(b(star fmt(%9.3f)) se(par)) ///
        stats(N r2 r2_vint r2_local, ///
              fmt(%7.0f %7.2f %7.2f %7.2f) ///
              labels("Observations" "Total R-squared" "GCD National Waves" ///
                     "All local determinants")) ///
        nolabel replace mlabels(none) collabels(none) ///
        starlevels(\$^{*}\$ .1 \$^{**}\$ .05 \$^{***}\$ .01) ///
        keep("") ///
        order("")

    di "Table saved: table_variance_${depvar}.tex"

    estimates clear
}

* ==================================================================
* End of script
* ==================================================================

di _n "All variance decomposition tables saved to: ${tables}"
