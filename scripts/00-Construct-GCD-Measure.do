* ==================================================================
* Garden Layout Metrics: Compute GCD Component Variables
* ==================================================================
*
* Description: Computes the four components of the Garden City Design
*   (GCD) index from street network data:
*   1. Curvature (osm_curvaturep75) - from convex hulls
*   2. Three-way intersections (osm_threeway_inter) - from network topology
*   3. Share of 90-degree angles (osm_share_angle90) - from block angles
*   4. Out-streets (osm_out_street) - from street connectivity
*
* Inputs (for each state):
*   - street_join_[STATE]_convex.csv (convex hull data)
*   - street_network_components_[STATE].csv (network topology)
*   - block_angles_states_[STATE].csv (block angle data)
*
* Outputs:
*   - garden_layout_metrics_US.dta
*
* ==================================================================

clear all
set maxvar 32000
set more off

* ------------------------------------------------------------------
* Setup: Set replication path (MODIFY THIS PATH FOR YOUR SYSTEM)
* ------------------------------------------------------------------

* UPDATE THIS PATH to the parent of the Replication folder (i.e., the folder that contains Replication/)
global replication_path "/path/to/parent/of/Replication"

* Define subdirectories
global convex_hulls "${replication_path}/Replication/data/raw/street_convex_hulls"
global network_components "${replication_path}/Replication/data/raw/street_network_components"
global block_angles "${replication_path}/Replication/data/raw/turning_distance_of_blocks"
global data_raw "${replication_path}/Replication/data/raw"

* ==================================================================
* SECTION 1: Create empty placeholder dataset
* ==================================================================

clear all
gen state = ""
gen osm_curvaturep75 = .
gen osm_threeway_inter = .
gen osm_share_angle90 = .
gen osm_out_street = .
gen ft_blc_state = ""

save "${data_raw}/garden_layout_metrics_US.dta", replace

* ==================================================================
* SECTION 2: Loop through all states
* ==================================================================

* 48 States (no data for Vermont)
foreach st_id in AZ AL AR CA CO CT DE DC FL GA ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VA WA WV WI WY {

    display _n "Processing state: `st_id'"
    
    * ------------------------------------------------------------------
    * 2.1 Calculate Curvature (from convex hulls)
    * ------------------------------------------------------------------
    
    import delimited "${convex_hulls}/street_join_`st_id'_convex.csv", clear
    
    cap: rename sum_length sum_newlen
    
    * Drop invalid observations
    drop if sum_newlen == 0
    drop if sum_newlen == .
    drop if mbg_length == .
    
    * Keep only segments from this state (boundary segments counted twice)
    split ft_bl__, p("-")
    drop if ft_bl__2 != " `st_id'"
    
    * Collapse by street name within neighborhood
    collapse (mean) sum_newlen (sum) mbg_length, by(name ft_bl__)
    
    * Calculate curvature
    gen curvature = sum_newlen / mbg_length
    replace mbg_length = sum_newlen if sum_newlen < mbg_length
    
    * Collapse to neighborhood level (75th percentile of curvature)
    collapse (p75) curvaturep75 = curvature [w=sum_newlen], by(ft_bl__)
    
    rename ft_bl__ ft_blc_state
    isid ft_blc_state
    
    keep ft_blc_state curvaturep75
    
    tempfile curvature
    save `curvature', replace
    
    * ------------------------------------------------------------------
    * 2.2 Calculate Three-way Intersections and Out-streets
    * ------------------------------------------------------------------
    
    import delimited "${network_components}/street_network_components_`st_id'.csv", clear
    
    tostring from to, replace
    
    * Expand to count each intersection from both directions
    expand 2
    sort ft_blc_ from to
    gen from_consolidated = from
    bysort ft_blc_: replace from_consolidated = to if 2 * floor(_n/2) == _n
    
    * Count streets meeting at each node
    bysort ft_blc_ from_consolidated: gen count_node = _N
    
    * Three-way intersection indicator
    gen threeway_inter = (count_node == 3)
    
    * Out-street indicator (streets connecting to other neighborhoods)
    gen out_street = 0
    replace out_street = 1 if (ft_blc_toneigh != ft_blc_fromneigh)
    replace out_street = 1 if (ft_blc_toneigh == "NA" & ft_blc_fromneigh == "NA")
    replace out_street = 1 if (ft_blc_toneigh != ft_blc_ | ft_blc_fromneigh != ft_blc_)
    
    * Collapse to neighborhood level
    collapse (firstnm) state (mean) threeway_inter out_street [iweight=1/count_node], by(ft_blc_)
    
    gen ft_blc_state = ft_blc_ + " " + "-" + " " + state
    drop ft_blc_
    
    tempfile intersection
    save `intersection', replace
    
    * ------------------------------------------------------------------
    * 2.3 Calculate Share of 90-degree Block Angles
    * ------------------------------------------------------------------
    
    import delimited "${block_angles}/block_angles_states_`st_id'.csv", varnames(nonames) clear
    
    sxpose, clear firstnames
    drop _var2
    
    * Parse neighborhood identifier
    split _var1, p(".")
    split _var11, p("_")
    gen ft_blc_ = _var113 + "_" + _var114
    
    isid ft_blc_
    
    gen ft_blc_state = ft_blc_ + " " + "-" + " " + "`st_id'"
    
    rename _var3 share_angle90
    destring share_angle90, replace force
    
    keep share_angle90 ft_blc_state
    
    tempfile sharedegreeblocks
    save `sharedegreeblocks', replace
    
    * ------------------------------------------------------------------
    * 2.4 Merge all components for this state
    * ------------------------------------------------------------------
    
    use `curvature', clear
    merge 1:1 ft_blc_state using `intersection', nogenerate
    merge 1:1 ft_blc_state using `sharedegreeblocks', nogenerate
    
    * Rename variables with osm_ prefix
    rename curvaturep75 osm_curvaturep75
    rename threeway_inter osm_threeway_inter
    rename share_angle90 osm_share_angle90
    rename out_street osm_out_street
    
    keep osm_curvaturep75 osm_threeway_inter osm_share_angle90 osm_out_street ft_blc_state state
    
    * Append to master dataset
    append using "${data_raw}/garden_layout_metrics_US.dta"
    save "${data_raw}/garden_layout_metrics_US.dta", replace
}

* ==================================================================
* SECTION 3: Finalize dataset
* ==================================================================

use "${data_raw}/garden_layout_metrics_US.dta", clear

* Keep only required variables
keep osm_curvaturep75 osm_threeway_inter osm_share_angle90 osm_out_street ft_blc_state state

save "${data_raw}/garden_layout_metrics_US.dta", replace

* ==================================================================
* End of script
* ==================================================================

di _n "Garden layout metrics saved to: ${data_raw}/garden_layout_metrics_US.dta"
di "Variables created:"
di "  - osm_curvaturep75"
di "  - osm_threeway_inter"
di "  - osm_share_angle90"
di "  - osm_out_street"
di "  - ft_blc_state"
di "  - state"
