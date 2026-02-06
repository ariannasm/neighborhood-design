#===============================================================================
# Figure SI4: Geographic coverage of urban areas
#
# Description: Creates map showing urban areas across the United States
# Input:  BUI2000_focal_vect_large shapefile
# Output: FigureSI4.pdf
#===============================================================================

library(sf)
library(ggplot2)
library(maps)

# Set project path
# UPDATE THIS PATH to your local Replication folder
project <- "/path/to/Replication"

# -------------------------------------------------------- #
#                       Load data
# -------------------------------------------------------- #
urb <- st_read(file.path(project, "data/raw"),
               layer = "BUI2000_focal_vect_large")

# US states basemap
USA_states <- map_data("state")

# -------------------------------------------------------- #
#                     Create Figure
# -------------------------------------------------------- #
colors <- c("Urban areas" = "#333063")

gg <- ggplot() +
  geom_polygon(data = USA_states, aes(x = long, y = lat, group = group),
               color = "#CFD0C6", fill = "#FFFFFF", size = 0.15) +
  geom_sf(data = urb, aes(fill = "Urban areas"),
          color = "#333063", size = 0.15, lwd = 0) +
  scale_fill_manual(values = colors, name = "") +
  scale_alpha(guide = 'none') +
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
    legend.key.height = unit(0.2, 'cm'),
    legend.key.width = unit(0.6, 'cm'),
    legend.background = element_rect(fill = alpha('white', 0)),
    legend.text = element_text(size = 9),
    legend.title = element_text(size = 8),
    legend.direction = "horizontal",
    legend.margin = margin(0, 0, 0, 0)
  )

ggsave(file.path(project, "figures/fig_SI4.pdf"),
       plot = gg, width = 9, height = 6.6, units = "in")
