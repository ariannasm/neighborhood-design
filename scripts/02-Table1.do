* ==================================================================
* Table: Summary Statistics
* ==================================================================
*
* Description: Creates summary statistics tables comparing:
*   - Full sample
*   - High GCD neighborhoods (garden_metric_osm_d == 1)
*   - Low GCD neighborhoods (garden_metric_osm_d == 0)
*
* Inputs:
*   - us_data_matching.dta
*
* Outputs:
*   - table_sum1_[varname].tex (means)
*   - table_sum2_[varname].tex (standard deviations)
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

* ==================================================================
* SECTION 1: Load and prepare data
* ==================================================================

use "${data_clean}/us_data_matching.dta", clear

* Rename long variable name for convenience
rename sg_social_mean_home_dwelltime sg_social_homedwell

* Create region indicator variables
gen Midwest = (region_name == "Midwest")
gen Northeast = (region_name == "Northeast")
gen South = (region_name == "South")
gen West = (region_name == "West")

* ==================================================================
* SECTION 2: Define program for summary statistics
* ==================================================================

* Program to generate summary statistics for a single variable
capture program drop gen_sumstats
program define gen_sumstats
    args var label
    
    * Open output files
    file open myfile1 using "${tables}/table_sum1_`var'.tex", write replace
    file open myfile2 using "${tables}/table_sum2_`var'.tex", write replace
    
    * Write row label
    file write myfile1 "\multirow{2}{7cm}{`label'\dotfill}&"
    file write myfile2 "&"
    
    * Full Sample
    sum `var'
    file write myfile1 %9.3f (r(mean)) " & "
    file write myfile2 " (" %9.3f (r(sd)) ") & "
    
    * High GCD Sample
    sum `var' if garden_metric_osm_d == 1
    file write myfile1 %9.3f (r(mean)) " & "
    file write myfile2 " (" %9.3f (r(sd)) ") & "
    
    * Low GCD Sample
    sum `var' if garden_metric_osm_d == 0
    file write myfile1 %9.3f (r(mean)) " \\  "
    file write myfile2 " (" %9.3f (r(sd)) ") \\ "
    
    * Close files
    file close myfile1
    file close myfile2
    
    di "Created summary stats for: `var'"
end

* ==================================================================
* SECTION 3: Generate summary statistics - Outcome variables
* ==================================================================

* Social isolation
gen_sumstats sg_log_interaction_norm "Log social isolation"

* Sedentarism (at-home time)
gen_sumstats sg_social_homedwell "Daily at-home time"

* Greenhouse gas emissions
gen_sumstats outcome_mob_GHG_all_trips "Annual ghg per person"

* ==================================================================
* SECTION 4: Generate summary statistics - Control variables
* ==================================================================

* Geographic controls
gen_sumstats controlsgeo_avg_elev "Elevation"
gen_sumstats controlsgeo_avg_slope "Slope"
gen_sumstats controlsgeo_neigh_latitude "Latitude"
gen_sumstats controlsgeo_neigh_longitude "Longitude"

* Distance to city center
gen_sumstats dist_2000_city_altpop_km "Distance to City Center (km)"

* ==================================================================
* SECTION 5: Generate summary statistics - Region shares
* ==================================================================

gen_sumstats Midwest "Share in Midwest"
gen_sumstats Northeast "Share in Northeast"
gen_sumstats South "Share in South"
gen_sumstats West "Share in West"

* ==================================================================
* End of script
* ==================================================================

di _n "Summary statistics tables saved to: ${tables}"
