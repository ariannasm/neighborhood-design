* ==================================================================
* Master Executer: Replication Package for Garden City Design Paper
* ==================================================================
*
* Description: Runs all scripts to reproduce tables and figures
*
* Note: R scripts (02-Figure2.R, 04-FigureSI4.R, 04-FigureSI6.R) must
*       be run separately in R/RStudio
*
* ==================================================================

clear all
set more off

* Set root directory (update this path to your local replication folder)
global root "."
global scripts "${root}/scripts"

* ==================================================================
* SECTION 0: Data Construction
* ==================================================================

* Construct GCD measure
do "${scripts}/00-Construct-GCD-Measure.do"

* Construct analysis dataset
do "${scripts}/01-Construct-Data.do"

* ==================================================================
* SECTION 1: Main Text - Figures
* ==================================================================

* Figure 1: GCD index distribution
do "${scripts}/02-Figure1.do"

* Figure 2: GCD index maps
* NOTE: Run separately in R: ${scripts}/02-Figure2.R

* Figure 3: Outcomes by distance to city center
do "${scripts}/02-Figure3.do"

* ==================================================================
* SECTION 2: Main Text - Tables
* ==================================================================

* Table 1: Summary statistics
do "${scripts}/02-Table1.do"

* Table 2: Main results (OLS and IV)
* Uses binary GCD measure (top 20% = high GCD)
global gdi garden_metric_osm_d
do "${scripts}/02-Table2.do"

* ==================================================================
* SECTION 3: Supplementary Tables SI1-SI2
* ==================================================================

* Table SI1: Complementary outcomes
do "${scripts}/03-TableSI1.do"

* Table SI2: OLS estimates with demographic and historical controls
do "${scripts}/03-TableSI2.do"

* ==================================================================
* SECTION 4: Supplementary Tables SI3-SI5 (via Table2.do)
* ==================================================================
* Note: These tables reuse 02-Table2.do with different GCD measures.
* The global "gdi" controls which measure is used:
*   - garden_metric_osm_d:     binary (top 20%) - used for Table 2
*   - garden_metric_osm:       continuous (0-1 scale) - used for Table SI3
*   - garden_metric_pca_d:     binary using PCA-based index - used for Table SI4
*   - garden_metric_osm_top33: binary (top 33%) - used for Table SI5

* Table SI3: OLS and IV estimates using the continuous GCD measure
global gdi garden_metric_osm
do "${scripts}/02-Table2.do"

* Table SI4: PCA-based GCD robustness
global gdi garden_metric_pca_d
do "${scripts}/02-Table2.do"

* Table SI5: Top-tercile GCD robustness
global gdi garden_metric_osm_top33
do "${scripts}/02-Table2.do"

* ==================================================================
* SECTION 5: Supplementary Tables SI6-SI12
* ==================================================================

* Table SI6: Covariate balance after matching
do "${scripts}/03-TableSI6.do"

* Table SI7: Variance decomposition of GCD
do "${scripts}/03-TableSI7.do"

* Table SI8: Controlling for residential zoning
do "${scripts}/03-TableSI8.do"

* Table SI9: IV robustness checks
do "${scripts}/03-TableSI9.do"

* Table SI10: Controlling for neighborhood age effects
do "${scripts}/03-TableSI10.do"

* Table SI11: Low-migration subsample
do "${scripts}/03-TableSI11.do"

* Table SI12: Census tract-level analysis
do "${scripts}/03-TableSI12.do"

* ==================================================================
* SECTION 6: Supplementary Figures
* ==================================================================

* Figure SI1: GCD validation using existing typologies
* NOTE: Requires restricted data from Wheeler (2008) and Talen (2022).
*       Run separately after obtaining the original data from the authors.
* do "${scripts}/04-FigureSI1.do"

* Figure SI2: Propensity score overlap
do "${scripts}/04-FigureSI2.do"

* Figure SI3: GCD and residential land use over time
do "${scripts}/04-FigureSI3.do"

* Figure SI4: Geographic coverage of urban areas
* NOTE: Run separately in R: ${scripts}/04-FigureSI4.R

* Figure SI5: GCD components by year and distance
do "${scripts}/04-FigureSI5.do"

* Figure SI6: Location of validation neighborhoods
* NOTE: Run separately in R: ${scripts}/04-FigureSI6.R
*       Requires restricted data from Wheeler (2008) and Talen (2022).

* Figure SI7: Distribution of neighborhoods by year built
do "${scripts}/04-FigureSI7.do"

* ==================================================================
* End of Executer
* ==================================================================

di _n "=============================================="
di "Replication complete!"
di "=============================================="
di _n "R scripts to run separately:"
di "  - 02-Figure2.R"
di "  - 04-FigureSI4.R"
di "  - 04-FigureSI6.R"
di "=============================================="
