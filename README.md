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

**[INSERT DROPBOX LINK HERE]**

After downloading, place the contents in `data/raw/` so that the folder structure matches the layout above.

> **Note:** If you only want to replicate the analysis (Sections 1 onward), the processed datasets in `data/clean/` are already included in this repository and sufficient for all tables and figures.

## Software Requirements

- **Stata** (version 15 or later)
- **R** (version 4.0 or later) with the following packages: `ggplot2`, `sf`, `tidyverse`

## How to Run

### Setup

Before running any script, update the file path at the top of each script to point to your local copy of this replication folder. Each script contains:

```stata
* UPDATE THIS PATH to your local Replication folder
global replication_path "/path/to/Replication"
```

or for R scripts:

```r
# UPDATE THIS PATH to your local Replication folder
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

## License

This replication package is provided for academic use. Please cite the paper if you use this code or data.
