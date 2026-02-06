* ==================================================================
* Table SI6: Covariate balance after matching
* ==================================================================
*
* Description: Creates balance table comparing High-GCD vs Low-GCD
*   neighborhoods on geographic covariates, both unweighted and
*   with inverse probability weights (IPW).
*
* Columns:
*   (1) High-GCD unweighted mean (SD)
*   (2) Low-GCD unweighted mean (SD)
*   (3) High-GCD IPW-weighted mean (SE)
*   (4) Low-GCD IPW-weighted mean (SE)
*   (5) Weighted difference and p-value
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - table_balance_sum1_[var].tex (means)
*   - table_balance_sum2_[var].tex (SDs/SEs/p-values)
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

* Region dummies
gen Midwest = (region_name == "Midwest")
gen Northeast = (region_name == "Northeast")
gen South = (region_name == "South")
gen West = (region_name == "West")

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

* Geographic controls for propensity score
global geo_controls i.state_enc ///
                    controlsgeo_avg_elev ///
                    controlsgeo_avg_slope ///
                    i.controlsgeo_ecozonesl1_enc ///
                    controlsgeo_neigh_longitude ///
                    controlsgeo_neigh_latitude

* ==================================================================
* SECTION 3: Estimate propensity score and IPW weights
* ==================================================================

* Propensity score model
probit garden_metric_osm_d ${dist} ${geo_controls}

* Predicted probabilities
predict double pscore if e(sample), pr

* IPW weights
gen double ipw = .
replace ipw = 1 / pscore if garden_metric_osm_d == 1 & e(sample)
replace ipw = 1 / (1 - pscore) if garden_metric_osm_d == 0 & e(sample)

* Mark estimation sample
gen byte in_est = e(sample)

* ==================================================================
* SECTION 4: Create balance table
* ==================================================================

* ------------------------------------------------------------------
* 4.1 Define covariates and labels
* ------------------------------------------------------------------

local covars ///
    controlsgeo_avg_elev ///
    controlsgeo_avg_slope ///
    dist_2000_city_altpop_km ///
    Midwest ///
    Northeast ///
    South ///
    West ///
    controlsgeo_neigh_latitude ///
    controlsgeo_neigh_longitude

label var controlsgeo_avg_elev "Elevation"
label var controlsgeo_avg_slope "Slope"
label var dist_2000_city_altpop_km "Distance to City Center (km)"
label var Midwest "Share in Midwest"
label var Northeast "Share in Northeast"
label var South "Share in South"
label var West "Share in West"
label var controlsgeo_neigh_longitude "Longitude"
label var controlsgeo_neigh_latitude "Latitude"

* ------------------------------------------------------------------
* 4.2 Generate balance statistics for each covariate
* ------------------------------------------------------------------

foreach v of local covars {
    local lbl : variable label `v'

    * Open files for means (sum1) and SDs/p-values (sum2)
    file open myfile1 using "${tables}/table_balance_sum1_`v'.tex", write replace
    file open myfile2 using "${tables}/table_balance_sum2_`v'.tex", write replace

    file write myfile1 "\multirow{2}{7cm}{`lbl'\dotfill}&"
    file write myfile2 "&"

    * --- High-GCD unweighted ---
    quietly summarize `v' if garden_metric_osm_d == 1
    file write myfile1 %9.3f (r(mean)) " & "
    file write myfile2 " (" %9.3f (r(sd)) ") & "

    * --- Low-GCD unweighted ---
    quietly summarize `v' if garden_metric_osm_d == 0
    file write myfile1 %9.3f (r(mean)) " & "
    file write myfile2 " (" %9.3f (r(sd)) ") & "

    * --- High-GCD weighted ---
    quietly mean `v' [pw=ipw] if garden_metric_osm_d == 1 & in_est == 1
    matrix M = r(table)
    file write myfile1 %9.3f (M[1,1]) " & "
    file write myfile2 " (" %9.3f (M[2,1]) ") & "

    * --- Low-GCD weighted ---
    quietly mean `v' [pw=ipw] if garden_metric_osm_d == 0 & in_est == 1
    matrix M = r(table)
    file write myfile1 %9.3f (M[1,1]) " & "
    file write myfile2 " (" %9.3f (M[2,1]) ") & "

    * --- Weighted regression for diff + p-value ---
    quietly regress `v' garden_metric_osm_d [pw=ipw] if in_est == 1, cluster(controlsgeo_county)
    local diff = _b[garden_metric_osm_d]
    local pval = 2 * ttail(e(df_r), abs(_b[garden_metric_osm_d] / _se[garden_metric_osm_d]))

    file write myfile1 %9.3f (`diff') " \\ "
    file write myfile2 " [$ p=$" %9.3f (`pval') "] \\ "

    file close myfile1
    file close myfile2

    di "Balance stats saved for: `v'"
}

* ==================================================================
* End of script
* ==================================================================

di _n "All balance tables saved to: ${tables}"
