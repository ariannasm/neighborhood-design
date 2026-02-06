/*==============================================================================
 Figure SI7: Distribution of neighborhoods by year built

 Description: Bar chart showing distribution of neighborhoods by first year built
 Input:  us_data_matching.dta
 Output: fig_SI7.pdf
==============================================================================*/

clear all
* UPDATE THIS PATH to your local Replication folder
global project "/path/to/Replication"

* Colors
global blue_dark "51 48 99"

* -------------------------------------------------------- *
                    * Load data *
* -------------------------------------------------------- *
use "$project/data/clean/us_data_matching.dta", clear

* Keep only neighborhoods within 45 km of city center
keep if dist_2000_city_altpop_km <= 45

* -------------------------------------------------------- *
            * Compute share by year *
* -------------------------------------------------------- *
gen counter = 1
collapse (sum) total_neigh_by_year = counter, by(first_year_built)

drop if first_year_built > 2000

egen sum_neigh = sum(total_neigh_by_year)
gen share = total_neigh_by_year / sum_neigh

* -------------------------------------------------------- *
                * Create Figure *
* -------------------------------------------------------- *
twoway (bar share first_year_built, fcolor("${blue_dark}") lwidth(none) barwidth(4.5)), ///
    graphregion(color(white)) bgcolor(white) ///
    xsize(5) ysize(5) scale(1) ///
    ylabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
    xlabel(, labsize(medlarge) tlcolor("black") glcolor("145 168 208")) ///
    yscale(lstyle(none)) ///
    xscale(lstyle(none)) ///
    plotregion(lcolor(black) lwidth(thin)) ///
    xtitle("Year of development", size(5)) ///
    ytitle("Share of neighborhoods developed", size(5))

graph export "$project/figures/fig_SI7.pdf", as(pdf) replace
