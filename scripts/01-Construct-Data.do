* ==================================================================
* Data Preparation: Garden City Design Analysis
* ==================================================================
*
* Description: Prepares the analysis dataset by:
*   1. Loading neighborhood characteristics
*   2. Merging vintages, regions, distances, and controls
*   3. Computing the Garden City Design (GCD) index
*   4. Computing PCA-based alternative index
*   5. Merging outcome variables
*   6. Constructing social isolation measure
*
* Inputs (all from data/raw):
*   - BUI2000_average_USneighborhoods.csv
*   - footprints_blockgroup_first_year_built.csv
*   - neighborhoods_match_regions.csv
*   - distances_us_alt2_city2000.csv
*   - grid_metric_US.dta
*   - US_neighborhood_location_controls.csv
*   - us_migration_rate_clean.dta
*   - garden_layout_metrics_US.dta
*   - census_blockgroup_footprints_within.csv
*   - us_outcome_isolation_clean.dta
*   - us_outcome_safegraph_poi_clean.dta
*   - us_outcome_walkability_clean.dta
*   - us_outcome_smartlocation_clean.dta
*   - us_outcome_census2000_blkgrp_clean.dta
*   - us_outcome_census2000_tract_clean.dta
*   - us_outcome_wfh_clean.dta
*   - us_bui_1900.csv
*   - us_outcome_safegraph_distance_clean.dta
*   - gcd-neighbors.csv
*
* Outputs (all to data/clean):
*   - garden_measure_US.dta
*   - garden_measure_US_map.csv
*   - garden_measure_US_metro_map.csv
*   - garden_measure_US_urb_map.csv
*   - us_data_matching.dta
*   - us_data_matching.csv
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
global data_raw "${replication_path}/data/raw"
global data_clean "${replication_path}/data/clean"

* ==================================================================
* SECTION 1: Load building intensity data
* ==================================================================

import delimited "${data_raw}/BUI2000_average_USneighborhoods.csv", clear

rename ft_bl__ ft_blc_state
rename gridcode mean_bui_1900

keep ft_blc_state mean_bui_1900 

tempfile bui
save `bui', replace

* ==================================================================
* SECTION 2: Load and process vintage data
* ==================================================================

import delimited "${data_raw}/footprints_blockgroup_first_year_built.csv", clear

keep ft_bl__ gridcode
rename ft_bl__ ft_blc_state
rename gridcode first_year_built

* Clean invalid years
replace first_year_built = . if first_year_built == 0
replace first_year_built = . if first_year_built == 1

* Create vintage indicators
gen vintage_1900_1925 = (first_year_built >= 1900 & first_year_built <= 1925)
gen vintage_1926_1950 = (first_year_built > 1925 & first_year_built <= 1950)
gen vintage_1951_1975 = (first_year_built > 1950 & first_year_built <= 1975)
gen vintage_1976_2000 = (first_year_built > 1975 & first_year_built <= 2000)

tempfile year_vintage
save `year_vintage', replace

* ==================================================================
* SECTION 3: Load regions data
* ==================================================================

import delimited "${data_raw}/neighborhoods_match_regions.csv", clear

drop v1

* Keep only US neighborhoods
keep if d_ushc == 0

rename regionce region_code
rename name region_name
rename ft_bl__ ft_blc_state

keep ft_blc_state region_code region_name

tempfile us_regions
save `us_regions', replace

* ==================================================================
* SECTION 4: Load distance to city data
* ==================================================================

import delimited "${data_raw}/distances_us_alt2_city2000.csv", clear

drop v1

* Convert distance to km
gen dist_2000_city_altpop_km = distance_alt2_city2000 / 1000

keep ft_blc_state dist_2000_city_altpop_km

tempfile distance_to_city_pop_2000_alt
save `distance_to_city_pop_2000_alt', replace

* ==================================================================
* SECTION 5: Load grid index (Boeing)
* ==================================================================

use "${data_raw}/grid_metric_US.dta", clear

xtile griddedness_sum_quint = griddedness_sum, n(5)
gen griddedness_sum_d = (griddedness_sum_quint == 5)

keep griddedness_sum_d ft_blc_state

tempfile grid
save `grid', replace

* ==================================================================
* SECTION 6: Load geographic controls
* ==================================================================

import delimited "${data_raw}/US_neighborhood_location_controls.csv", clear

drop v1
rename ft_bl__ ft_blc_state

keep controlsgeo_avg_elev controlsgeo_avg_slope controlsgeo_ecozonesl1 ///
     controlsgeo_state controlsgeo_county controlsgeo_neigh_longitude ///
     controlsgeo_neigh_latitude controlsgeo_metro controlsplan_areaneigh_mts ///
     ft_blc_state gisjoin

tempfile controls
save `controls', replace

* ==================================================================
* SECTION 7: Load urban boundary indicator
* ==================================================================

import delimited "${data_raw}/census_blockgroup_footprints_within.csv", clear

rename ft_bl__ ft_blc_state
gen d_within_urban = 1

keep ft_blc_state d_within_urban foot_id

tempfile within
save `within', replace

* ==================================================================
* SECTION 8: Merge all neighborhood characteristics
* ==================================================================

* Start with garden layout metrics
use "${data_raw}/garden_layout_metrics_US.dta", clear

* Merge all datasets
merge 1:1 ft_blc_state using `bui', nogenerate
merge 1:1 ft_blc_state using `year_vintage', nogenerate
merge 1:1 ft_blc_state using `us_regions', nogenerate
merge 1:1 ft_blc_state using `distance_to_city_pop_2000_alt', nogenerate
merge 1:1 ft_blc_state using `grid', keep(1 3) nogenerate
merge 1:1 ft_blc_state using `controls', keep(1 3) nogenerate
merge 1:1 ft_blc_state using `within', keep(1 3) nogenerate

* Create county ID for migration merge
gen state_drop = substr(gisjoin, 1, 3)
replace state_drop = substr(state_drop, 2, 2)
gen county_drop = substr(gisjoin, 5, 3)
gen countyID_2000 = state_drop + county_drop
drop state_drop county_drop

* Merge migration rates
merge m:1 countyID_2000 using "${data_raw}/us_migration_rate_clean.dta", keep(1 3) nogenerate

* Drop county ID (recreated later)
drop countyID_2000

* Clean indicator variables
replace d_within_urban = 0 if d_within_urban == .

* Restrict to neighborhoods within urban boundaries (MUST happen before standardization)
keep if d_within_urban == 1

* ==================================================================
* SECTION 9: Standardize layout variables and compute GCD index
* ==================================================================

* Fix curvature values
replace osm_curvaturep75 = 1 if osm_curvaturep75 <= 1

* Standardize each component
foreach var in curvaturep75 threeway_inter share_angle90 out_street {
    
    * Winsorize at 1st and 99th percentiles
    winsor2 osm_`var', cuts(1 99) replace
    
    sum osm_`var', d
    
    * Standardize with respect to sample mean and SD
    gen std_osm_`var' = (-(osm_`var' - r(mean)) / r(sd)) if osm_`var' != .
    
    * Adjust sign for curvature and three-way intersection
    if "`var'" == "curvaturep75" | "`var'" == "threeway_inter" {
        replace std_osm_`var' = -std_osm_`var'
    }
}

* Compute GCD index as average of standardized components
gen garden_metric_osm = (std_osm_curvaturep75 + std_osm_threeway_inter + ///
                         std_osm_share_angle90 + std_osm_out_street) / 4
						 

* ==================================================================
* SECTION 10: Compute PCA-based alternative index
* ==================================================================

* Run PCA on the four standardized features
pca std_osm_curvaturep75 std_osm_threeway_inter std_osm_share_angle90 std_osm_out_street

* Predict first principal component
predict garden_metric_pca1 if e(sample), score

* Create quintiles and binary indicator
xtile garden_metric_pca1_quint = garden_metric_pca1, n(5)
gen garden_metric_pca_d = (garden_metric_pca1_quint == 5)

* ==================================================================
* SECTION 11: Create derived variables
* ==================================================================

* Keep only observations with valid GCD
keep if garden_metric_osm != .


* Encode categorical variables
encode state, gen(state_enc)
encode controlsgeo_ecozonesl1, gen(controlsgeo_ecozonesl1_enc)

* Log distance
gen log_dist_2000_city_altpop_km = log(dist_2000_city_altpop_km)

* Distance deciles
xtile dist_2000_city_altpop_km_dec = dist_2000_city_altpop_km, n(10)

* GCD quintiles and binary indicators
xtile garden_metric_osm_quint = garden_metric_osm, n(5)
gen garden_metric_osm_d = (garden_metric_osm_quint == 5)

xtile garden_metric_osm_terc = garden_metric_osm, nq(3)
gen garden_metric_osm_top33 = (garden_metric_osm_terc == 3)

* Rescale continuous GCD to 0-1 range
sum garden_metric_osm
replace garden_metric_osm = (garden_metric_osm - r(min)) / (r(max) - r(min))

* Decade of first year built
gen decade_first_year = floor(first_year_built / 10) * 10

* Create tract and county IDs
gen cbgID_2000 = ft_blc_
split cbgID_2000, p("_")
replace cbgID_20001 = subinstr(cbgID_20001, " ", "", .)
drop cbgID_2000 cbgID_20002
rename cbgID_20001 cbgID_2000

gen tractID_2000 = substr(cbgID_2000, 1, strlen(cbgID_2000) - 1)

gen countyID_2000 = substr(ft_blc_state, 1, strlen(ft_blc_state) - 20)
replace countyID_2000 = subinstr(countyID_2000, "G", "", 1)

* ==================================================================
* SECTION 12: Save intermediate GCD measure files
* ==================================================================

save "${data_clean}/garden_measure_US.dta", replace

* Export for map visualization (neighborhood level)
export delimited using "${data_clean}/garden_measure_US_map.csv", replace

* Export metro-level aggregation
preserve
collapse (mean) garden_metric_osm, by(controlsgeo_metro)
export delimited using "${data_clean}/garden_measure_US_metro_map.csv", replace
restore

* Export urban area-level aggregation
preserve
collapse (mean) garden_metric_osm, by(foot_id)
export delimited using "${data_clean}/garden_measure_US_urb_map.csv", replace
restore

* ==================================================================
* SECTION 13: Merge outcome variables
* ==================================================================

* ------------------------------------------------------------------
* 13.1 Social isolation data
* ------------------------------------------------------------------

merge 1:1 gisjoin using "${data_raw}/us_outcome_isolation_clean.dta", ///
    keepusing(gisjoin sg_local_visitors sg_foreign_visitors) keep(1 3) nogenerate

* ------------------------------------------------------------------
* 13.2 SafeGraph POI data
* ------------------------------------------------------------------

merge 1:1 ft_blc_state using "${data_raw}/us_outcome_safegraph_poi_clean.dta", ///
    keepusing(ft_blc_state outcome_poi_total_norm) keep(1 3) nogenerate

* ------------------------------------------------------------------
* 13.3 Walkability data
* ------------------------------------------------------------------

merge 1:1 ft_blc_state using "${data_raw}/us_outcome_walkability_clean.dta", ///
    keep(1 3) nogenerate

* ------------------------------------------------------------------
* 13.4 Smart location (mobility/emissions) data
* ------------------------------------------------------------------

preserve
use "${data_raw}/us_outcome_smartlocation_clean.dta", clear
keep if ft_blc_state != ""

keep outcome_mob_Annual_GHG outcome_mob_VMT_per_wo outcome_mob_NonCom_VMT ///
     outcome_mob_Pct_AO0 outcome_mob_Pct_AO1 outcome_mob_Pct_AO2p ft_blc_state

* Convert from pounds to tons
replace outcome_mob_Annual_GHG = outcome_mob_Annual_GHG * 0.000453592

* Compute emissions per mile
gen emission_per_mile = outcome_mob_Annual_GHG / (outcome_mob_VMT_per_wo * 260)

* Compute GHG for all trips
gen outcome_mob_GHG_commute = outcome_mob_VMT_per_wo * emission_per_mile * 260
gen outcome_mob_GHG_noncommute = outcome_mob_NonCom_VMT * emission_per_mile * 365
gen outcome_mob_GHG_all_trips = outcome_mob_GHG_commute + outcome_mob_GHG_noncommute

tempfile mob
save `mob', replace
restore

merge 1:1 ft_blc_state using `mob', keep(1 3) nogenerate

* ------------------------------------------------------------------
* 13.5 Census 2000 block group data
* ------------------------------------------------------------------

preserve
use "${data_raw}/us_outcome_census2000_blkgrp_clean.dta", clear
keep if ft_blc_state != ""

keep census2000blkgp_dem_SH_white census2000blkgp_fam_SH_married ///
     census2000blkgp_dem_SH_somecoll census2000blkgp_dem_MED_age ///
     census2000blkgp_income_pc census2000blkgp_dem_total_pop ft_blc_state

tempfile census
save `census', replace
restore

merge 1:1 ft_blc_state using `census', keep(1 3) nogenerate

* ------------------------------------------------------------------
* 13.6 Census 2000 tract data
* ------------------------------------------------------------------

merge m:1 tractID_2000 using "${data_raw}/us_outcome_census2000_tract_clean.dta", ///
    keep(1 3) keepusing(census2000tct_dem_SH_white census2000tct_fam_SH_married ///
    census2000tct_dem_SH_somecoll census2000tct_dem_MED_age census2000tct_income_PERCAP) ///
    nogenerate

* ------------------------------------------------------------------
* 13.7 Work from home data
* ------------------------------------------------------------------

merge m:1 tractID_2000 using "${data_raw}/us_outcome_wfh_clean.dta", ///
    keep(1 3) keepusing(tractID_2000 wfh_share) nogenerate

* ------------------------------------------------------------------
* 13.8 Historical built-up intensity (1900)
* ------------------------------------------------------------------

preserve
import delimited "${data_raw}/us_bui_1900.csv", varnames(1) clear
drop v1

tempfile bui_1900
save `bui_1900', replace
restore

merge 1:1 gisjoin using `bui_1900', keep(1 3) nogenerate force

* ------------------------------------------------------------------
* 13.9 SafeGraph distance/dwelling data
* ------------------------------------------------------------------

preserve
use "${data_raw}/us_outcome_safegraph_distance_clean.dta", clear
keep if ft_blc_state != ""

keep sg_social_mean_home_dwelltime sg_social_cand_device_count ///
     sg_social_mean_dist_trav_FH ft_blc_state

tempfile safegraph
save `safegraph', replace
restore

merge 1:1 ft_blc_state using `safegraph', keep(1 3) nogenerate

* ------------------------------------------------------------------
* 13.10 GCD of neighboring areas
* ------------------------------------------------------------------

preserve
import delimited "${data_raw}/gcd-neighbors.csv", varnames(1) clear

destring gcd_2km gcd_5km, replace force
drop v1

tempfile gcd_neighbors
save `gcd_neighbors', replace
restore

merge 1:1 ft_blc_state using `gcd_neighbors', keep(1 3) nogenerate

* ------------------------------------------------------------------
* 13.11 Parcel-level zoning data
* ------------------------------------------------------------------

merge 1:1 ft_blc_state using "${data_raw}/outcome_parcels_neigh_clean.dta", ///
    keep(1 3) nogenerate

* ==================================================================
* SECTION 14: Construct social isolation measure
* ==================================================================

* Share of local visitors
gen share_local_visit = sg_local_visitors / census2000blkgp_dem_total_pop
winsor2 share_local_visit, cuts(0 99) replace

* Share of foreign visitors
gen share_visitors = sg_foreign_visitors / (sg_local_visitors + sg_foreign_visitors)

* Log social isolation index (negative of log interaction)
gen sg_log_interaction_norm = -log((share_local_visit) * (share_visitors))

* ==================================================================
* SECTION 15: Save final analysis dataset
* ==================================================================

save "${data_clean}/us_data_matching.dta", replace

export delimited using "${data_clean}/us_data_matching.csv", replace

* ==================================================================
* End of script
* ==================================================================

di _n "Data preparation complete."
di "Files saved to: ${data_clean}"
di _n "Output files:"
di "  - garden_measure_US.dta"
di "  - garden_measure_US_map.csv"
di "  - garden_measure_US_metro_map.csv"
di "  - garden_measure_US_urb_map.csv"
di "  - us_data_matching.dta"
di "  - us_data_matching.csv"
