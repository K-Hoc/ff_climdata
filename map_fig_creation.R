############################################
# Packages
############################################
library(sf)
library(terra)
library(tidyverse)
library(ggplot2)
library(ggspatial)
library(ggnewscale)
library(rnaturalearth)
library(rosm)
library(elevatr)
library(patchwork)
library(tidyterra)
library(ggpubr)

############################################
# Global settings
############################################
CRS_WGS84 <- "EPSG:4326"  # storage / input only
CRS_GK3   <- "EPSG:31467" # legacy DWD
CRS_PROJ  <- "EPSG:3035"  # plotting + raster math

############################################
# Helper functions
############################################
# Load country boundary
load_country <- function(name, crs = CRS_PROJ) {
  ne_countries(
    country = name,
    scale = "medium",
    returnclass = "sf"
  ) |>
    st_transform(crs)
}

# Crop raster to country outline
crop_mask <- function(r, country_sf) {
  v <- vect(country_sf)
  r |>
    crop(v, snap = "out") |>
    mask(v)
}

# Raster prejection
fix_and_project_raster <- function(
    r,
    country_sf,
    src_crs,
    dst_crs = CRS_PROJ,
    method = "bilinear"
) {
  crs(r) <- src_crs
  country_src <- vect(country_sf) |> project(src_crs)
  
  r |>
    crop(country_src, snap = "out") |>
    mask(country_src) |>
    project(dst_crs, method = method)
}

# Create dataframe from raster
raster_to_df <- function(r, value_name = "value", transform = identity) {
  as.data.frame(r, xy = TRUE, na.rm = TRUE) |>
    rename(!!value_name := 3) |>
    mutate(!!value_name := transform(.data[[value_name]]))
}

# Computing hillshade
compute_hillshade <- function(dem) {
  dem_m <- project(dem, CRS_PROJ)
  
  slope  <- terrain(dem_m, "slope", unit = "radians")
  aspect <- terrain(dem_m, "aspect", unit = "radians")
  
  shade(slope, aspect)
}

# Function to plot temperature map
plot_temperature_map_spat <- function(
    temp_rast,      # SpatRaster (projected, e.g. EPSG:3035)
    hill_rast,      # SpatRaster (same CRS)
    country_sf,     # sf (same CRS)
    osm_bg,         # SpatRaster (same CRS)
    title
) {
  bbox <- st_bbox(country_sf)
  
  ggplot() +
    # OSM background
    # annotation_spatial(osm_bg) +
    
    # Hillshade
    geom_spatraster(data = hill_rast, alpha = 0.4) +
    scale_fill_gradient(
      low = "black",
      high = "white",
      na.value = "white",
      guide = "none"
    ) +
    
    ggnewscale::new_scale_fill() +
    
    # Temperature raster
    geom_spatraster(data = temp_rast, alpha = 0.75) +
    scale_fill_viridis_c(
      name = "Temperature (°C)",
      na.value = "white",
      # limits = c(-3, 12)
    ) +
    
    # Country outline
    geom_sf(
      data = country_sf,
      fill = NA,
      color = "black",
      linewidth = 0.8
    ) +
    
    # Scale bar
    annotation_scale(
      location = "bl",
      width_hint = 0.25,
      pad_x = unit(0.1, "cm"),
      pad_y = unit(0.1, "cm")
    ) +
    
    # North arrow
    annotation_north_arrow(
      location = "tl", # top-left
      which_north = "true",
      style = north_arrow_fancy_orienteering,
      pad_x = unit(0.05, "cm"),
      pad_y = unit(0.05, "cm")
    ) +
    
    # Correct projected coordinates
    coord_sf(
      crs = st_crs(country_sf),
      xlim = c(bbox["xmin"], bbox["xmax"]),
      ylim = c(bbox["ymin"], bbox["ymax"]),
      expand = FALSE
    ) +
    
    labs(title = title) +
    theme_minimal() +
    theme(
      # legend.position = "none",
      panel.grid = element_blank(),
      panel.background = element_rect(fill = "white", colour = NA),
      plot.background = element_rect(fill = "white", colour = NA),      
      #axis.text = element_blank(),
      #axis.ticks = element_blank(),
      #axis.title = element_blank()
    )
}


############################################
# Data preparation
############################################

# Country boundary
country <- load_country("Germany")

#------------------------------------------------
# Temperature rasters
#------------------------------------------------
temp_dwd_raw  <- rast("../1_dataRaw/raster/TADXMM_17_1981_30.asc")
temp_euro_raw <- rast("../../euro-cordex/historical/mean_historic_mat.tif")
temp_10k <- rast("tif/10k_clim_cl.tif")

# EURO‑CORDEX (WGS84)
temp_euro <- temp_euro_raw |>
  project(CRS_PROJ) |>
  crop_mask(country)
temp_euro <- temp_euro - 273.15

# DWD GK3 -> LAEA (wrong CRS → fix, crop, reproject)
temp_dwd <- fix_and_project_raster(
  r = temp_dwd_raw,
  country_sf = country,
  src_crs = CRS_GK3
)

temp_10k <- fix_and_project_raster(
  temp_10k,
  country_sf = country,
  src_crs = CRS_GK3
)
temp_10k_mean <- mean(temp_10k[[c(1, 2)]])

#------------------------------------------------
# Raster → data frames
#------------------------------------------------
temp_df_dwd <- raster_to_df(
  temp_dwd,
  value_name = "temp",
  transform = \(x) x / 10
)

temp_df_euro <- raster_to_df(
  temp_euro,
  value_name = "temp",
  # transform = \(x) x - 273.15
)

temp_df_10k <- raster_to_df(
  temp_10k,
  value_name = "max_tmp"
)
temp_df_10k_mean <- raster_to_df(
  temp_10k,
  value_name = "mean"
)

#------------------------------------------------
# Hillshade
#------------------------------------------------
dem <- get_elev_raster(
  # locations = country,
  locations = st_transform(country, CRS_WGS84),
  z = 6,
  clip = "locations"
) |>
  rast() |>
  project(CRS_PROJ)

hill <- compute_hillshade(dem)

hill_df <- raster_to_df(
  hill,
  value_name = "hillshade"
)

#------------------------------------------------
# OpenStreetMap basemap (FIXED)
#------------------------------------------------
osm_bg <- osm.raster(
  x = st_transform(country, CRS_WGS84),
  zoom = 6,
  type = "osm"
) |>
  rast() |>
  project(CRS_PROJ)


############################################
# Maps
############################################
map_dwd <- plot_temperature_map_spat(
  temp_rast = temp_dwd,
  hill_rast = hill,
  country_sf = country,
  osm_bg = osm_bg,
  title = "Temperature: DWD"
)

map_euro <- plot_temperature_map_spat(
  temp_rast = temp_euro,
  hill_rast = hill,
  country_sf = country,
  osm_bg = osm_bg,
  title = "Temperature: EURO CORDEX"
)

map_10k <- plot_temperature_map_spat(
  temp_rast = temp_10k[["max_tmp_cent"]],
  hill_rast = hill,
  country_sf = country,
  osm_bg = osm_bg,
  title = "Temperature: 10k cluster"
)

map_10k_mean <- plot_temperature_map_spat(
  temp_rast = temp_10k_mean,
  hill_rast = hill,
  country_sf = country,
  osm_bg = osm_bg,
  title = "Temperature: 10k cluster"
)
############################################
# Combine maps
############################################
map_dwd + map_10k + map_euro + plot_annotation(tag_levels = "A")

map_10k + map_euro + plot_annotation(tag_levels = "A") #+ plot_layout(guides = "collect")
map_10k_mean + map_euro + plot_annotation(tag_levels = "A")
# map_10k_mean + map_euro + plot_annotation(tag_levels = "A") + plot_layout(guides = "collect")
ggsave(
  filename = "output/ger_10keur.tif",
  scale = 3,
  width = 90,
  height = 45,
  units = "mm",
  dpi = 500
)

ggsave(
  filename = "output/fig3.pdf",
  scale = 3,
  width = 90,
  height = 45,
  units = "mm",
  dpi = 500
)



############################################
# Figure 2 creation
############################################
df_f2maps <- readRDS("output/fig2_maps.rds")
df_f2dens <- readRDS("output/fig2_dens.rds")

# Compute common bounding box
bboxes <- list(
  c(xmin = 3280415, ymin = 5237501, xmax = 3920415, ymax = 6100501),
  c(xmin = 3280415, ymin = 5237501, xmax = 3920415, ymax = 6100501),
  c(xmin = 3280415, ymin = 5237501, xmax = 3920415, ymax = 6100501)
)

xmin <- min(sapply(bboxes, function(x) x["xmin"]))
xmax <- max(sapply(bboxes, function(x) x["xmax"]))
ymin <- min(sapply(bboxes, function(x) x["ymin"]))
ymax <- max(sapply(bboxes, function(x) x["ymax"]))

coord_common <- coord_sf(
  xlim = c(xmin, xmax),
  ylim = c(ymin, ymax),
  expand = FALSE
)

cfacet_names <- c(
  "max_temp_anomaly" = "max. temperature",
  "min_temp_anomaly" = "min. temperature",
  "prec_anomaly" = "precipitation",
  "rad_anomaly" = "rad",
  "vpd_anomaly" = "vpd"
)

# Common theme + color scale
common_theme <- theme_pubr() +
  theme(
    legend.title.position = "top",
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5, face = "bold")
  )

color_scale <- scale_color_viridis_c(
  option = "plasma",
  direction = 1,
  name = "Cluster"
)

p_dens <- ggplot(data = df_f2dens) +
  geom_vline(linetype = 4, xintercept = 0) +
  geom_freqpoly(
    aes(
      x = anomaly_val,
      colour = nr_cl
    ),
    bins = 100,
    linewidth = 0.8,
    alpha = 0.8
  ) +
  facet_wrap(
    ~ anomaly_param,
    ncol = 1,
    nrow = 5,
    scales = "free",
    labeller = labeller(anomaly_param = cfacet_names)
  ) +
  labs(
    colour = "Number of Clusters",
    x = "Difference to cluster mean"
  ) +
  theme(
    legend.title.position = "top",
    legend.position = "bottom",
    plot.margin     = margin(2, 2, 2, 2),
    panel.spacing   = unit(2, "pt"),
    strip.text      = element_text(margin = margin(1, 1, 1, 1)),
    legend.box.margin = margin(t = 0, r = 0, b = 0, l = 0),
    legend.margin     = margin(0, 0, 0, 0)
  ) +
  scale_colour_viridis_d(
    option = "plasma",
    name = "Number of Clusters"
  )

df_f2maps_s <- st_simplify(df_f2maps, dTolerance = 150)
# A discrete Viridis scale; use _d for discrete, not _c
p_left <- ggplot(df_f2maps_s) +
  facet_wrap(~nr_clst, nrow = 3, ncol = 1) +
  geom_sf(aes(color = cluster_mod), size = 0.2) +
  ## Scale bar
  #annotation_scale(
  #  data = data.frame(
  #    nr_clst = factor(
  #      tail(levels(df_f2maps_s$nr_clst), 1),
  #      levels = levels(df_f2maps_s$nr_clst)
  #    )
  #  ),
  #  location = "tr",
  #  width_hint = 0.25,
  #  pad_x = unit(0.05, "cm"),
  #  pad_y = unit(0.05, "cm")
  #) +
  ## North arrow
  #annotation_north_arrow(
  #  data = data.frame(
  #    nr_clst = factor(
  #      head(levels(df_f2maps_s$nr_clst), 1),
  #      levels = levels(df_f2maps_s$nr_clst)
  #    )
  #  ),
  #  location = "tr",
  #  which_north = "true",
  #  style = north_arrow_fancy_orienteering,
  #  height = unit(0.7, "cm"),
  #  width = unit(0.7, "cm"),
  #  pad_x = unit(0.05, "cm"),
  #  pad_y = unit(0.05, "cm")
  #) +
  MetBrewer::scale_color_met_d("Redon") +
  coord_common +
  common_theme +
  theme(
    legend.position = "none", # "right",
    plot.margin = margin(2,2,2,2),
    panel.spacing = unit(2, "pt"),
    strip.text = element_text(margin = margin(1, 1, 1, 1))
  )

## North arrow -----------------------------------------------------------
#p_arrow <- ggplot() +
#  annotation_north_arrow(
#    location = "tl",
#    #which_north = "true",
#    style = north_arrow_fancy_orienteering,
#    height = unit(1, "cm"),
#    width = unit(1, "cm")
#  ) +
#  theme_void() +
#  theme(
#    rect = element_blank(),
#    plot.background = element_rect(fill = NA, colour = NA)
#  )
#
## Combine ---------------------------------------------------------------
#p_left_fin <- p_left +
#  inset_element(
#    p_arrow,
#    left = 0.7,
#    bottom = 0.9,
#    right = 0.85,
#    top = 1,
#    on_top = TRUE,
#    align_to = "plot"
#  )
#p_left_fin

p_dens <- p_dens + common_theme
p_fin <- (p_left | p_dens) +
  plot_annotation(tag_levels = "A") +
  plot_layout(widths = c(1,2))

p_fin

ggsave(
  filename = "output/Fig2_noarrowscale.pdf",
  plot = p_fin,
  device = cairo_pdf,
  width = 190,
  height = 280,
  units = "mm",
  dpi = 300
)

ggsave(
  filename = "output/Fig2_noarrowscale.tiff",
  plot = p_fin,
  width = 190,
  height = 280,
  units = "mm",
  dpi = 300
)
