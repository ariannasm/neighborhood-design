/*==============================================================================
 Figure SI3: GCD and residential land use over time

 Description: Shows temporal trends in residential share and GCD measure
 Input:  us_data_matching.dta
 Output: fig_SI3.pdf
==============================================================================*/

clear all
* UPDATE THIS PATH to your local Replication folder
global project "/path/to/Replication"

* Colors
global orange_dark "243 102 40"
global blue_dark "51 48 99"

* -------------------------------------------------------- *
        * Compute mean + CI for Share Residential *
* -------------------------------------------------------- *
use "$project/data/clean/us_data_matching.dta", clear

gen year_5 = floor(first_year_built/5)*5

collapse (mean) outcome_parcel_res_comb (semean) se_bd = outcome_parcel_res_comb, by(year_5)

gen ci_low_bd = outcome_parcel_res_comb - 1.96 * se_bd
gen ci_high_bd = outcome_parcel_res_comb + 1.96 * se_bd
gen tag_bd = 1
rename outcome_parcel_res_comb outcome_mean_bd
rename year_5 first_year_built

tempfile bd
save `bd', replace

* -------------------------------------------------------- *
        * Compute mean + CI for GCD *
* -------------------------------------------------------- *
use "$project/data/clean/us_data_matching.dta", clear

gen year_5 = floor(first_year_built/5)*5

collapse (mean) garden_metric_osm (semean) se_gd = garden_metric_osm, by(year_5)

gen ci_low_gd = garden_metric_osm - 1.96 * se_gd
gen ci_high_gd = garden_metric_osm + 1.96 * se_gd
gen tag_gd = 1
rename garden_metric_osm garden_mean
rename year_5 first_year_built

tempfile gd
save `gd', replace

* -------------------------------------------------------- *
                    * Create Figure *
* -------------------------------------------------------- *
use `bd', clear
merge 1:1 first_year_built using `gd', nogenerate

twoway ///
    (connected outcome_mean_bd first_year_built if tag_bd == 1 & inrange(outcome_mean_bd, 0.4, 0.7), sort yaxis(1) ///
        ylabel(0.4(0.1)0.7, axis(1) labsize(large) tlcolor("black") glcolor("145 168 208")) ///
        color("${orange_dark}") msymbol(circle) msize(0.8)) ///
    (rarea ci_low_bd ci_high_bd first_year_built if tag_bd == 1 & inrange(ci_low_bd, 0.45, 0.65), sort yaxis(1) ///
        color("243 102 40%10") lwidth(vthin)) ///
    (connected garden_mean first_year_built if tag_gd == 1, sort yaxis(2) ///
        ylabel(, axis(2) labsize(large) tlcolor("black") glcolor("145 168 208")) ///
        ytitle("", axis(2) size(5)) color("${blue_dark}") msymbol(circle) msize(0.8)) ///
    (rarea ci_low_gd ci_high_gd first_year_built if tag_gd == 1, sort yaxis(2) ///
        color("51 48 99%10") lwidth(vthin)), ///
    ytitle("", size(5)) ///
    xtitle("Years", size(5)) ///
    yscale(lstyle(none)) ///
    xscale(lstyle(none)) ///
    xlabel(, labsize(large) tlcolor("black") glcolor("145 168 208")) ///
    legend(region(lwidth(none)) pos(11) ring(0) rows(1) keygap(0.5) colgap(0.1) ///
           size(small) symysize(0.85) symxsize(15) ///
           order(1 "Share Residential" "(left axis)" 3 "GCD" "(right axis)") stack) ///
    xsize(5) ysize(5) scale(1) ///
    graphregion(color(white)) bgcolor(white) ///
    plotregion(lcolor(black) lwidth(thin))

graph export "$project/figures/fig_SI3.pdf", as(pdf) replace
