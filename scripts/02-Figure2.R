# ==================================================================
# Figure 2: GCD index maps
# ==================================================================
# 
# Description: Creates a panel figure showing:
#   A) Main US map of GCD aggregated to urban areas
#   B) Detailed city inset maps for 5 selected cities
#
# Inputs:
#   - garden_measure_US_map.csv (neighborhood-level GCD data)
#   - garden_measure_US_urb_map.csv (urban area-level GCD data)
#   - Various shapefiles (neighborhoods, states, metros, etc.)
#
# Outputs:
#   - fig_2.pdf
#
# ==================================================================

# ------------------------------------------------------------------
# Setup: Set replication path (MODIFY THIS PATH FOR YOUR SYSTEM)
# ------------------------------------------------------------------

# Set the base path to the replication folder
# UPDATE THIS PATH to your local Replication folder
replication_path <- "/path/to/Replication"

# Define subdirectories
data_raw_path <- file.path(replication_path, "data", "raw")
data_clean_path <- file.path(replication_path, "data", "clean")
figures_path <- file.path(replication_path, "figures")

# ------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------

library(tmap)
library(ggplot2)
library(sf)
library(scales)
library(tidyverse)
library(dplyr)
library(ggspatial)
library(maps)
library(extrafont)
library(grid)
library(gridExtra)
library(tmaptools)
library(OpenStreetMap)

theme_set(theme_bw())
sf_use_s2(FALSE)
# ------------------------------------------------------------------
# Load fonts (optional - comment out if fonts not available)
# ------------------------------------------------------------------

# font_import(paths = "/Users/ariannasalazarmiranda/Library/Fonts")
# font_import()
# loadfonts()

# ==================================================================
# SECTION 1: Load and prepare data
# ==================================================================

# ------------------------------------------------------------------
# 1.1 Load neighborhood-level GCD data
# ------------------------------------------------------------------

garden <- read.csv(file.path(data_clean_path, "garden_measure_US_map.csv"))
garden <- garden[, c("ft_blc_state", "garden_metric_osm")]
garden <- garden[!(is.na(garden$ft_blc_state) | garden$ft_blc_state == ""), ]

# ------------------------------------------------------------------
# 1.2 Load shapefiles
# ------------------------------------------------------------------

# Census block group footprints (neighborhoods)
neigh <- st_read(dsn = data_raw_path, layer = "footprints_blockgroup_msa") %>%
  st_transform(4326)

# Metropolitan areas (2000)
metro_2000_sf <- st_read(dsn = data_raw_path, layer = "US_msacmsa_2000_simplified") %>%
  st_transform(4326) %>%
  st_buffer(dist = 0)  # Fix invalid geometries


# ------------------------------------------------------------------
# 1.3 Merge neighborhood shapefile with GCD data
# ------------------------------------------------------------------

# Rename ID column for merging
names(neigh)[names(neigh) == "ft_bl__"] <- "ft_blc_state"

# Merge and keep only necessary columns
neigh_merge_garden <- merge(neigh, garden, by = 'ft_blc_state')
neigh_merge_garden <- neigh_merge_garden[, c("ft_blc_state", "garden_metric_osm", "geometry")]
neigh_merge_garden <- neigh_merge_garden[!(is.na(neigh_merge_garden$garden_metric_osm) | 
                                             neigh_merge_garden$garden_metric_osm == ""), ]

# ------------------------------------------------------------------
# 1.4 Load urban area-level GCD data (for main map)
# ------------------------------------------------------------------

# Dissolved urban areas shapefile
urb <- st_read(dsn = data_raw_path, layer = "footprints_blockgroup_msa_dissolved_urb") %>%
  st_transform(4326)

# Urban area GCD values
garden_urb <- read.csv(file.path(data_clean_path, "garden_measure_US_urb_map.csv"))

# Merge
urb_merge_garden <- merge(urb, garden_urb, by = 'foot_id')

# ==================================================================
# SECTION 2: Prepare legend breaks and color mapping
# ==================================================================

# ------------------------------------------------------------------
# 2.1 Define breaks for GCD categories
# ------------------------------------------------------------------

# Fixed breaks for the color scale
breaks <- c(0, 0.2, 0.3, 0.4, 0.5, 0.7, 1)
pretty_breaks5 <- c(0.2, 0.3, 0.4, 0.5, 0.7)

# Get data range for legend
urb_merge_garden_df <- urb_merge_garden %>%
  st_drop_geometry() %>%
  as.data.frame()

minVal5 <- min(urb_merge_garden_df$garden_metric_osm, na.rm = TRUE)
maxVal5 <- round(max(urb_merge_garden_df$garden_metric_osm, na.rm = TRUE))

# Compute labels for legend
labels5 <- c()
brks5 <- c(minVal5, pretty_breaks5, maxVal5)

for (idx in 1:length(brks5)) {
  labels5 <- c(labels5, round(brks5[idx + 1], 2))
}
labels5 <- labels5[1:length(labels5) - 1]

# ------------------------------------------------------------------
# 2.2 Add categorical breaks to urban data
# ------------------------------------------------------------------

urb_merge_garden$brks5 <- cut(urb_merge_garden$garden_metric_osm,
                              breaks = brks5,
                              labels = labels5,
                              include.lowest = TRUE)

brks_scale5 <- levels(urb_merge_garden$brks5)
labels_scale5 <- rev(brks_scale5)

# ------------------------------------------------------------------
# 2.3 Define color palette and mapping
# ------------------------------------------------------------------

# Colors: LOW GCD (orange) to HIGH GCD (dark blue)
cbp1 <- c("#e69750", "#f06627", "#569eba", "#4a72ad", "#454c93", "#333063")

# Create explicit named color vector
color_mapping <- setNames(cbp1, brks_scale5)

# ==================================================================
# SECTION 3: Prepare city labels for main map
# ==================================================================

# ------------------------------------------------------------------
# 3.1 Load US cities data and select capitals
# ------------------------------------------------------------------

state <- map_data("state")
data(us.cities)

# State capitals (excluding Alaska and Hawaii)
us.capitals_main2 <- us.cities %>% 
  filter(capital == 2, !country.etc %in% c("AK", "HI"))

# Convert to sf
cities_centroids2 <- st_as_sf(us.capitals_main2, coords = c("long", "lat"), crs = 4326)

# ------------------------------------------------------------------
# 3.2 Get GCD values for cities and select top/bottom 10
# ------------------------------------------------------------------

# Spatial join to get GCD values
urb_selected2 <- urb_merge_garden[cities_centroids2, ]
d2 <- st_join(cities_centroids2, urb_selected2, join = st_intersects)

# Top 10 highest GCD
max_cities <- d2 %>%
  arrange(desc(garden_metric_osm)) %>%
  slice(1:10)

# Top 10 lowest GCD
min_cities <- d2 %>%
  arrange(garden_metric_osm) %>%
  slice(1:10)

# Combine and prepare for plotting
cities <- rbind(max_cities, min_cities)
centres <- as.data.frame(st_coordinates(cities))
cities.df <- cbind(st_drop_geometry(cities), centres)
names(cities.df)[names(cities.df) == "X"] <- "X"
names(cities.df)[names(cities.df) == "Y"] <- "Y"

# ==================================================================
# SECTION 4: Create main US map (Panel A)
# ==================================================================

legend_title <- "GCD"

gg <- ggplot() +
  # State boundaries
  geom_polygon(data = state, aes(x = long, y = lat, group = group),
               color = "#CFD0C6", fill = "#FFFFFF", size = 0.15) +
  # Metro area boundaries (invisible, for extent)
  geom_sf(data = metro_2000_sf, color = NA, fill = NA, size = 0.15) +
  # GCD values by urban area
  geom_sf(data = urb_merge_garden, aes(fill = brks5, color = brks5), size = 0.15) +
  # City labels
  geom_text(data = cities.df, aes(x = X, y = Y, label = name), 
            size = 2, vjust = 1, hjust = 1) +
  # Color scale for fill
  scale_fill_manual(legend_title, 
                    values = color_mapping,
                    na.value = "#BFBFB8", 
                    guide = guide_legend(
                      direction = "horizontal",
                      title.position = 'top',
                      title.hjust = 0.5,
                      label.hjust = 0.8,
                      nrow = 1,
                      byrow = TRUE,
                      reverse = FALSE,
                      label.position = "bottom",
                      override.aes = list(color = NA),
                      keywidth = unit(0.8, "cm"),
                      keyheight = unit(0.25, "cm"))) +
  # Color scale for border (hidden from legend)
  scale_colour_manual(values = color_mapping, na.value = "#BFBFB8", guide = "none") +
  xlab("") + 
  ylab("") +
  theme_bw() +
  theme(
    panel.grid.major = element_line(color = gray(.01), size = 0.01),
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "#FFFFFF"),
    axis.line = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks = element_blank(),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    legend.position = c(0.95, 0.95),
    legend.justification = c("right", "top"),
    legend.key = element_rect(color = NA, fill = NA),
    legend.background = element_rect(fill = alpha('white', 0), color = NA),
    legend.text = element_text(size = 7),
    legend.title = element_text(size = 8),
    legend.direction = "horizontal",
    legend.key.spacing.x = unit(-0.15, 'cm'),
    legend.margin = margin(0, 0, 0, 0)
  )
gg

# ==================================================================
# SECTION 5: Create city inset maps (Panel B)
# ==================================================================

sf::sf_use_s2(FALSE)

maps_usage <- list()

# ------------------------------------------------------------------
# 5.1 Mapbox basemap setup
# ------------------------------------------------------------------

apiKey <- paste0("?access_token=",
                 "pk.eyJ1IjoidGlua2VyMDAiLCJhIjoiY2txcXc5cXQ4MThmYTJ2cDVucWxtMzl6MyJ9.47m5wR15DSo75OF1SFO1_Q")
baseUrl <- "https://api.mapbox.com/styles/v1/tinker00/cl1l4sz87008h14n4fjfbv8qt/tiles/{z}/{x}/{y}"

# ------------------------------------------------------------------
# 5.2 Select cities for inset maps
# ------------------------------------------------------------------

us.capitals_main <- us.cities %>% filter(!country.etc %in% c("AK", "HI"))
cities_centroids <- st_as_sf(us.capitals_main, coords = c("long", "lat"), crs = 4326)

# Select 5 cities
cities_centroids_sub <- subset(cities_centroids,
                               name %in% c("Cambridge MA", "Philadelphia PA", 
                                           "Phoenix AZ", "Sacramento CA", 
                                           "Salt Lake City UT"))
# Rename Cambridge to Boston (same metro area)
cities_centroids_sub$name[cities_centroids_sub$name == "Cambridge MA"] <- "Boston MA"

# ------------------------------------------------------------------
# 5.3 Prepare neighborhood-level data for selected cities
# ------------------------------------------------------------------

# Get urban areas for selected cities
urb_selected <- urb_merge_garden[cities_centroids_sub, ]
d <- st_join(urb_selected, cities_centroids_sub, join = st_intersects)

# Remove urban-level GCD to avoid column collision in join
d <- d %>% select(-garden_metric_osm, -brks5)

# Prepare neighborhood data
neigh_merge_garden_sf <- neigh_merge_garden[, c("ft_blc_state", "geometry", "garden_metric_osm")]
neigh_merge_garden_sf <- neigh_merge_garden_sf[!(is.na(neigh_merge_garden_sf$garden_metric_osm) |
                                                   neigh_merge_garden_sf$garden_metric_osm == ""), ]

# Select neighborhoods within selected urban areas
neighs_selected <- neigh_merge_garden_sf[d, ]

# Join with city names
data <- st_join(neighs_selected, d, largest = TRUE)
data$NAME <- data$name

# ------------------------------------------------------------------
# 5.4 Create individual city maps
# ------------------------------------------------------------------

msas <- c('Philadelphia PA', 'Boston MA', 'Sacramento CA', 
          'Phoenix AZ', 'Salt Lake City UT')

for (name in msas) {
  name_id <- name
  subset_data <- filter(data, NAME == name_id) %>%
    st_transform(3857)
  
  bbox <- bb(subset_data, width = 35000, height = 35000)
  basemap <- read_osm(bbox, type = paste0(baseUrl, apiKey))
  
  maps_usage[[name]] <- tm_shape(basemap) +
    tm_rgb() +
    tm_shape(subset_data, bbox = bbox) +
    tm_fill("garden_metric_osm",
            palette = cbp1,
            breaks = c(0, 0.2, 0.3, 0.4, 0.5, 0.7, 1),
            style = "fixed") +
    tm_layout(fontfamily = 'Helvetica',
              legend.show = FALSE,
              main.title = subset_data$name[1],
              main.title.size = 0.75,
              title.position = c('center', 'bottom'),
              asp = 1)
}

# ==================================================================
# SECTION 6: Combine panels and export figure
# ==================================================================

height_1 <- 0.55

pdf(file = file.path(figures_path, "fig_2.pdf"),
    width = 9, height = 6.6)

# ------------------------------------------------------------------
# 6.1 Panel A: Main US map (top)
# ------------------------------------------------------------------

top_vp <- viewport(x = 0, y = 1 - height_1,
                   width = 1, height = height_1,
                   layout = grid.layout(nrow = 1, ncol = 1, widths = c(1)),
                   just = c("left", "bottom"))
pushViewport(top_vp)
print(gg, vp = viewport(layout.pos.col = 1, layout.pos.row = 1))
popViewport()

# ------------------------------------------------------------------
# 6.2 Panel B: City inset maps (bottom)
# ------------------------------------------------------------------

bottom_vp <- viewport(x = 0, y = 0.1,
                      layout = grid.layout(nrow = 1, ncol = 7,
                                           heights = c(.5, .5),
                                           widths = c(0.1625, 0.1625, 0.1625, 0.1625,
                                                      0.1625, 0.1625, 0.1625)),
                      width = 1, height = 1 - height_1,
                      just = c("left", "bottom"))
pushViewport(bottom_vp)

for (i in 1:length(maps_usage)) {
  print(maps_usage[[i]], vp = viewport(layout.pos.col = i + 1, layout.pos.row = 1))
}

popViewport()

# ------------------------------------------------------------------
# 6.3 Add panel labels
# ------------------------------------------------------------------

grid.text("A", x = 0.1, y = .98, gp = gpar(fontfamily = "Helvetica", fontface = "bold"))
grid.text("B", x = 0.1, y = 1 - height_1 - 0.03, gp = gpar(fontfamily = "Helvetica", fontface = "bold"))
grid.text("GCD", x = 0.13, y = (1 - height_1) * 0.75 - 0.025,
          gp = gpar(fontfamily = "Helvetica", fontsize = 11), rot = 90)

dev.off()

# ==================================================================
# End of script
# ==================================================================

cat("\nFigure saved to:", file.path(figures_path, "fig_2.pdf"), "\n")