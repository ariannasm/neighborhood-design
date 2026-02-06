/*==============================================================================
 Figure SI2: Propensity score overlap

 Description: Creates propensity score overlap plot for GCD treatment
 Input:  us_data_matching.dta
 Output: fig_SI2.pdf
==============================================================================*/

clear all
* UPDATE THIS PATH to your local Replication folder
global project "/path/to/Replication"

* Colors
global orange_dark "243 102 40"
global blue_dark "51 48 99"

* -------------------------------------------------------- *
                    * Load data *
* -------------------------------------------------------- *
use "$project/data/clean/us_data_matching.dta", clear

* -------------------------------------------------------- *
                * Create required variables *
* -------------------------------------------------------- *
* Distance bins
gen dist_bins = floor(dist_2000_city_altpop_km/5)*5

* Encode geographic variables
encode controlsgeo_metro, gen(controlsgeo_metro_enc)

* -------------------------------------------------------- *
                * Define matching sample *
* -------------------------------------------------------- *
gen control_group = 1 if garden_metric_osm_d == 0
gen treatment_group = 1 if garden_metric_osm_d == 1

bysort state_enc controlsgeo_metro_enc: egen total_control = total(control_group)
bysort state_enc controlsgeo_metro_enc: egen total_treatment = total(treatment_group)

* Rename for cleaner output
rename garden_metric_osm_d GCD

* -------------------------------------------------------- *
                * Propensity Score Model *
* -------------------------------------------------------- *
teffects ipw (sg_log_interaction_norm) ///
    (GCD i.dist_bins i.state_enc i.controlsgeo_metro_enc ///
     controlsgeo_avg_elev controlsgeo_avg_slope ///
     i.controlsgeo_ecozonesl1_enc ///
     controlsgeo_neigh_longitude controlsgeo_neigh_latitude, probit) ///
    if total_control >= 3 & total_treatment >= 3, ///
    atet vce(cluster controlsgeo_county)

* -------------------------------------------------------- *
                * Create Overlap Figure *
* -------------------------------------------------------- *
teffects overlap, ptl(1) ///
    line1opts(lcolor("${orange_dark}") lwidth(medthick)) ///
    line2opts(lcolor("${blue_dark}") lwidth(medthick)) ///
    xtitle("Propensity Score", size(5)) ///
    ytitle("Density", size(5)) ///
    graphregion(color(white)) bgcolor(white) ///
    plotregion(lcolor(black) lwidth(thin)) ///
    yscale(lstyle(none)) ///
    xscale(lstyle(none)) ///
    legend(on ring(0) position(2) rows(2) region(lc(none)) ///
           order(1 "Low-GCD" 2 "High-GCD") ///
           keygap(*.5) rowgap(*.1) size(3) symxsize(*.5)) ///
    xsize(5) ysize(5) scale(1)

graph export "$project/figures/fig_SI2.pdf", as(pdf) replace
