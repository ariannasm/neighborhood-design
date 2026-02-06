# ==================================================================
# Figure SI6: Location of validation neighborhoods
# ==================================================================
#
# Description: Maps the locations of neighborhoods used for validation:
#   - Wheeler (2008) typologies
#   - Talen (2022) garden suburbs
#   - USHC historical projects
#
# Inputs (from data/raw):
#   - wheeler_join_neigh_bycentroid.csv
#   - footprints_blockgroup_msa.shp (for neighborhood centroids)
#   - GSpoints.shp (Talen garden suburbs)
#   - neighborhood_locations_polygon.shp (USHC boundaries)
#   - Table_TownPlanning.csv
#
# Inputs (from data/clean):
#   - garden_measure_US.dta
#
# Outputs (to figures):
#   - fig_SI6.pdf
#
# ==================================================================

# Load required packages
library(sf)
library(ggplot2)
library(dplyr)
library(maps)
library(haven)

sf::sf_use_s2(FALSE)

# ------------------------------------------------------------------
# Setup: Set replication path (MODIFY THIS PATH FOR YOUR SYSTEM)
# ------------------------------------------------------------------

# UPDATE THIS PATH to your local Replication folder
replication_path <- "/path/to/Replication"

data_raw <- file.path(replication_path, "data/raw")
data_clean <- file.path(replication_path, "data/clean")
figures <- file.path(replication_path, "figures")

# ==================================================================
# SECTION 1: Load US sample for filtering
# ==================================================================

# Load clean US GCD data to identify neighborhoods with valid GCD
us_gcd <- read_dta(file.path(data_clean, "garden_measure_US.dta"))
us_gcd <- us_gcd %>% filter(!is.na(garden_metric_osm))
valid_neighborhoods <- unique(us_gcd$ft_blc_state)

cat("US neighborhoods with valid GCD:", length(valid_neighborhoods), "\n")

# ==================================================================
# SECTION 2: Load Wheeler typologies
# ==================================================================

# Load Wheeler data (already joined to neighborhoods)
wheeler_df <- read.csv(file.path(data_raw, "wheeler_join_neigh_bycentroid.csv"))

# Keep last observation per neighborhood
wheeler_df <- wheeler_df %>%
  group_by(ft_bl__) %>%
  slice_tail(n = 1) %>%
  ungroup()

# Keep only typologies with >100 observations
type_counts <- wheeler_df %>%
  filter(!is.na(type)) %>%
  count(type) %>%
  filter(n > 100)

wheeler_df <- wheeler_df %>%
  filter(type %in% type_counts$type)

# Load neighborhood shapefile to get centroids
neighborhoods <- st_read(dsn = data_raw, layer = "footprints_blockgroup_msa")
neighborhoods <- st_transform(neighborhoods, crs = 4326)

# Get centroids of neighborhoods
neighborhoods_cent <- st_centroid(neighborhoods)

# Join Wheeler data to neighborhood centroids and filter to validation sample
wheeler_cent <- neighborhoods_cent %>%
  inner_join(wheeler_df, by = "ft_bl__") %>%
  filter(!is.na(type)) %>%
  filter(ft_bl__ %in% valid_neighborhoods)

cat("Wheeler neighborhoods:", nrow(wheeler_cent), "\n")

# ==================================================================
# SECTION 3: Load Talen typologies
# ==================================================================

# Load Talen shapefile
talen <- st_read(dsn = data_raw, layer = "GSpoints")
talen <- st_transform(talen, crs = 4326)

# Spatial join to get ft_bl__ from neighborhoods
talen_joined <- st_join(talen, neighborhoods[, "ft_bl__"])

# Keep only those that overlap with neighborhoods
talen_joined <- talen_joined[neighborhoods, ]

# Filter to garden suburb types and validation sample
talen_cent <- talen_joined %>%
  filter(TYPE %in% c("Garden Village (Automobile)",
                     "Garden Village (Railroad)",
                     "Garden Village (Streetcar)",
                     "Resort Garden Suburb")) %>%
  filter(ft_bl__ %in% valid_neighborhoods)

cat("Talen garden suburbs:", nrow(talen_cent), "\n")

# ==================================================================
# SECTION 4: Load USHC neighborhoods
# ==================================================================

# Load USHC shapefile
ushc <- st_read(dsn = data_raw, layer = "neighborhood_locations_polygon")
ushc <- st_transform(ushc, crs = 4326)

# Extract numeric ID from shps column (e.g., "ID01_boundary.shp" -> 1)
ushc <- ushc %>%
  mutate(id_extracted = as.numeric(gsub("ID([0-9]+)_.*", "\\1", shps)))

# Load georeferenced indicator
ushc_georef <- read.csv(file.path(data_raw, "Table_TownPlanning.csv"))
ushc_georef <- ushc_georef %>%
  filter(georefenced_d == 1)

# Filter USHC to georeferenced neighborhoods
ushc <- ushc %>%
  filter(id_extracted %in% ushc_georef$id_neigh)

ushc_cent <- st_centroid(ushc)

cat("USHC neighborhoods:", nrow(ushc_cent), "\n")

# ==================================================================
# SECTION 5: Create figure
# ==================================================================

# Get US states basemap
USA_states <- map_data("state")

# Define colors
colors <- c("Wheeler (2008)" = "#333063",
            "Talen (2022)" = "#579EBE",
            "USHC" = "#E79750")

# Create map
p <- ggplot() +
  # State boundaries
  geom_polygon(data = USA_states,
               aes(x = long, y = lat, group = group),
               color = "#303030", fill = "#FFFFFF", linewidth = 0.3) +
  # Wheeler points
  geom_sf(data = wheeler_cent,
          aes(color = "Wheeler (2008)"),
          size = 1, alpha = 0.4) +
  # Talen points
  geom_sf(data = talen_cent,
          aes(color = "Talen (2022)"),
          size = 1, alpha = 0.9) +
  # USHC points
  geom_sf(data = ushc_cent,
          aes(color = "USHC"),
          size = 1, alpha = 0.9) +
  # Styling
  scale_color_manual(values = colors, name = "") +
  theme_bw() +
  coord_sf() +
  theme(
    panel.grid.major = element_line(color = gray(0.01), linewidth = 0.01),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(fill = NA, linewidth = 1),
    axis.line = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks = element_blank(),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    legend.position = c(0.95, 0.95),
    legend.justification = c("right", "top"),
    legend.key.height = unit(0.2, 'cm'),
    legend.key.width = unit(0.6, 'cm'),
    legend.background = element_rect(fill = alpha('white', 0.5)),
    legend.text = element_text(size = 10),
    legend.title = element_text(size = 8),
    legend.direction = "horizontal",
    legend.margin = margin(0, 0, 0, 0)
  )

# Save figure
ggsave(file.path(figures, "fig_SI6.pdf"), plot = p, width = 10, height = 6)
