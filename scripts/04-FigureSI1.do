* ==================================================================
* Figure SI1: GCD validation using existing typologies
* ==================================================================
*
* Description: Compares the GCD measure against existing neighborhood
*   typologies (Wheeler, Talen) and USHC historical projects.
*
* Inputs (from data/raw):
*   - wheeler_join_neigh_bycentroid.csv
*   - talen_join_neigh_bycentroid.csv
*   - Table_HousingNeedProvision.csv (for USHC treatment)
*   - garden_layout_metrics_USHC_usingOSM.dta (for USHC GCD)
*
* Inputs (from data/clean):
*   - garden_measure_US.dta
*
* Outputs (to figures):
*   - fig_SI1.pdf
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
global figures "${replication_path}/figures"

* Set color
global blue_dark ""51 48 99"" 

* ==================================================================
* SECTION 1: Load US GCD data and merge typologies
* ==================================================================

use "${data_clean}/garden_measure_US.dta", clear

* Drop missing GCD values
drop if garden_metric_osm == .

* ------------------------------------------------------------------
* Merge Wheeler typologies
* ------------------------------------------------------------------

preserve
import delimited "${data_raw}/wheeler_join_neigh_bycentroid.csv", clear

rename ft_bl__ ft_blc_state
rename type type_wheeler

keep ft_blc_state type_wheeler

* Standardize type names
replace type_wheeler = "Upscale Enclave" if type_wheeler == "Upscale Enclaves"
replace type_wheeler = "Trailer Park" if type_wheeler == "Trailer Parks"
replace type_wheeler = "Airports" if type_wheeler == "airports"
replace type_wheeler = "Campus Old" if type_wheeler == "Campus_Old"

* Keep last observation per neighborhood
bysort ft_blc_state: keep if _n == _N

* Keep only types with sufficient observations
bysort type_wheeler: gen typefreq = _N
keep if typefreq > 100
drop typefreq

tempfile wheeler
save `wheeler', replace
restore

merge 1:1 ft_blc_state using `wheeler', keep(1 3) nogenerate

* ------------------------------------------------------------------
* Merge Talen typologies
* ------------------------------------------------------------------

preserve
import delimited "${data_raw}/talen_join_neigh_bycentroid.csv", clear

gen type_talen_d = 1
rename type type_talen
rename ft_bl__ ft_blc_state

keep ft_blc_state type_talen_d type_talen

* Keep unique observations
egen tag = tag(ft_blc_state)
keep if tag == 1

* Keep only garden-related types
keep if type_talen == "Garden Village (Automobile)" | ///
        type_talen == "Garden Village (Railroad)" | ///
        type_talen == "Garden Village (Streetcar)" | ///
        type_talen == "Resort Garden Suburb"

drop tag

tempfile talen
save `talen', replace
restore

merge 1:1 ft_blc_state using `talen', keep(1 3) nogenerate
replace type_talen_d = 0 if type_talen_d == .

* Mark as US sample
gen d_ushc = 0

* Save US data
tempfile us_data
save `us_data', replace

* ==================================================================
* SECTION 2: Construct USHC sample with GCD and treatment
* ==================================================================

* Load USHC layout metrics
use "${data_raw}/garden_layout_metrics_USHC_usingOSM.dta", clear

* Standardize layout variables (same as US sample)
replace osm_curvaturep75 = 1 if osm_curvaturep75 <= 1

foreach var in curvaturep75 threeway_inter share_angle90 out_street {
    winsor2 osm_`var', cuts(1 99) replace
    sum osm_`var', d
    gen std_osm_`var' = (-(osm_`var' - r(mean)) / r(sd)) if osm_`var' != .

    if "`var'" == "curvaturep75" | "`var'" == "threeway_inter" {
        replace std_osm_`var' = -std_osm_`var'
    }
}

* Compute GCD index
gen garden_metric_osm = (std_osm_curvaturep75 + std_osm_threeway_inter + ///
                         std_osm_share_angle90 + std_osm_out_street) / 4

* Rescale to 0-1 range (using same approach as US)
sum garden_metric_osm
replace garden_metric_osm = (garden_metric_osm - r(min)) / (r(max) - r(min))

* Keep only needed variables
keep id_neigh garden_metric_osm

* Merge georeferenced indicator from TownPlanning data
preserve
import delimited "${data_raw}/Table_TownPlanning.csv", clear

* Format id_neigh to string
tostring id_neigh, format(%02.0f) replace force

keep id_neigh georefenced_d

tempfile ushc_georef
save `ushc_georef', replace
restore

* Merge georeferenced indicator
tostring id_neigh, replace
merge 1:1 id_neigh using `ushc_georef', keep(1 3) nogenerate

* Keep only georeferenced USHC neighborhoods
keep if georefenced_d == 1

* Mark as USHC sample
gen d_ushc = 1

* Keep only needed variables for append
keep garden_metric_osm d_ushc

* ==================================================================
* SECTION 3: Append US and USHC data
* ==================================================================

append using `us_data'

* ==================================================================
* SECTION 4: Compute statistics for figure
* ==================================================================

local ltit "GCD"

* Generate mean and N for all USHC neighborhoods
sum garden_metric_osm if d_ushc == 1, d
scalar ushc_mean = r(mean)
scalar ushc_n = r(N)

* Generate mean and N for Talen garden suburbs
sum garden_metric_osm if type_talen_d == 1, d
scalar talen_mean = r(mean)
scalar talen_n = r(N)

* Overall statistics (US sample only for reference lines)
sum garden_metric_osm if d_ushc == 0, d
local mean_all = r(mean)
quietly _pctile garden_metric_osm if d_ushc == 0, p(80)
local p80 = r(r1)

* Store sample sizes by Wheeler typology for later display
preserve
keep if type_wheeler != "" & d_ushc == 0
collapse (mean) garden_metric_osm (count) n_neighborhoods = garden_metric_osm, by(type_wheeler)
tempfile wheeler_counts
save `wheeler_counts', replace
restore

* ==================================================================
* SECTION 5: Collapse by Wheeler typology
* ==================================================================

keep if type_wheeler != ""

collapse (mean) garden_metric_osm, by(type_wheeler)

* Add Talen row
set obs `=_N + 1'
replace type_wheeler = "Garden Suburbs (Talen)" in `=_N'
replace garden_metric_osm = talen_mean in `=_N'

* Add USHC row
set obs `=_N + 1'
replace type_wheeler = "USHC" in `=_N'
replace garden_metric_osm = ushc_mean in `=_N'

* Sort and create position variable
sort garden_metric_osm
gen posnew = _n

* Create labels
labmask posnew, values(type_wheeler)

* ==================================================================
* SECTION 6: Create figure
* ==================================================================

twoway (bar garden_metric_osm posnew, horizontal barwidth(.7) color(${blue_dark})) ///
       (bar garden_metric_osm posnew if type_wheeler == "Garden Suburb + Village*", ///
            horizontal barwidth(.7) color(${blue_dark})) ///
       (bar garden_metric_osm posnew if type_wheeler == "USHC", ///
            horizontal barwidth(.7) color(${blue_dark})), ///
    xline(`mean_all', lpattern(dash) lcolor(gs8)) ///
    xline(`p80', lpattern(dash) lcolor(gs8)) ///
    text(1 `mean_all' "Mean", placement(east)) ///
    text(1 `p80' "Top 20%", placement(east)) ///
    yscale(lstyle(none)) ///
    xscale(lstyle(none)) ///
    ylabel(1(1)12, angle(horizontal) valuelabel labsize(medlarge) ///
           tlcolor("black") glcolor("145 168 208")) ///
    xlabel(0(0.1)0.7, valuelabel labsize(medlarge) ///
           tlcolor("black") glcolor("145 168 208")) ///
    xtitle("`ltit'", size(5)) ///
    ytitle("Typologies", size(5)) ///
    xsize(9) ysize(5) scale(1) ///
    graphregion(color(white)) bgcolor(white) ///
    plotregion(fcolor(white) lcolor(black) lwidth(vthin)) ///
    legend(off)

graph export "${figures}/fig_SI1.pdf", as(pdf) replace

* ==================================================================
* SECTION 7: Print sample sizes for figure caption
* ==================================================================

di _n "=============================================="
di "SAMPLE SIZES FOR FIGURE CAPTION"
di "=============================================="

* Load Wheeler counts and display
use `wheeler_counts', clear
sort garden_metric_osm
list type_wheeler n_neighborhoods, noobs clean

di _n "Additional categories:"
di "  Garden Suburbs (Talen): n = " talen_n
di "  USHC: n = " ushc_n

di _n "=============================================="
di "Figure SI1 complete."
di "Output saved to: ${figures}/fig_SI1.pdf"
