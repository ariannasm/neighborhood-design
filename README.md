# Replication Package: Neighborhood Design and the Environmental and Social Costs of Suburbanization

**Author:** Arianna Salazar-Miranda

## Overview

This repository contains the code, processed data, and output needed to replicate all tables and figures in the paper. Due to file size constraints, the raw input data is hosted separately (see below).

## Directory Structure

```
Replication/
├── scripts/        # Stata (.do) and R (.R) analysis scripts
├── data/
│   ├── clean/      # Processed datasets (included in this repo)
│   └── raw/        # Raw input data (download separately, see below)
├── figures/        # Output figures (PDF)
├── tables/         # Output tables (TeX)
└── README.md
```

## Raw Data Download

The `data/raw/` folder (~2.6 GB) is required to run the data construction scripts (Section 0) but is too large for GitHub. Download it from:

**[Download raw data from Dropbox](https://www.dropbox.com/scl/fo/yhqp9irdrhzex2num5m6i/AF2Sl_hD8WHGb8cg2_Oogk4?rlkey=cnyxg81z3oo8ywf9wu3nb4ibl&dl=0)**

After downloading, place the contents in `data/raw/` so that the folder structure matches the layout above.

> **Note:** If you only want to replicate the analysis (Sections 1 onward), the processed datasets in `data/clean/` are already included in this repository and sufficient for all tables and figures.

### Restricted Data (Figures SI1 and SI6)

Figures SI1 and SI6 require neighborhood location data from Wheeler (2008) and Talen (2022) that cannot be redistributed. To reproduce these figures, researchers must obtain the original data directly from the authors. All other tables and figures replicate fully without these data.

## Software Requirements

- **Stata** (version 15 or later) with the following user-written packages (install via `ssc install`):
  `reghdfe`, `ivreghdfe`, `estout`, `labmask`
- **R** (version 4.0 or later) with the following packages:
  `tidyverse`, `sf`, `ggplot2`, `tmap`, `tmaptools`, `OpenStreetMap`, `scales`, `dplyr`, `ggspatial`, `maps`, `extrafont`, `grid`, `gridExtra`, `haven`

## How to Run

### Setup

Before running the scripts, update the replication path to point to your local copy of this folder:

**Stata scripts:** Update the path **only in `scripts/Executer.do`** — all other `.do` scripts inherit it automatically:

```stata
* UPDATE THIS PATH ONLY (all individual scripts inherit it from here)
global replication_path "/path/to/Replication"
```

**R scripts:** Update `replication_path` at the top of each R script individually:

```r
# Set the base path to the replication folder
replication_path <- "/path/to/Replication"
```

### Full Replication

To reproduce all results, open `scripts/Executer.do` in Stata and run it. This master script calls all Stata do-files in sequence:

1. **Section 0** - Data construction (requires raw data)
2. **Section 1** - Main figures (Figures 1, 3)
3. **Section 2** - Main tables (Tables 1, 2)
4. **Sections 3-5** - Supplementary tables (Tables SI1-SI12)
5. **Section 6** - Supplementary figures (Figures SI1-SI3, SI5, SI7)

Three R scripts must be run separately in R/RStudio:
- `02-Figure2.R` (Figure 2)
- `04-FigureSI4.R` (Figure SI4)
- `04-FigureSI6.R` (Figure SI6)
