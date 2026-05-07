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
    scale_fill_viridis_c(name = "Temperature (°C)", na.value = "white") +
    
    # Country outline
    geom_sf(
      data = country_sf,
      fill = NA,
      color = "black",
      linewidth = 0.8
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
      legend.position = "none",
      panel.grid = element_blank(),
      panel.background = element_rect(fill = "white", colour = NA),
      plot.background = element_rect(fill = "white", colour = NA),      
      axis.text = element_blank(),
      axis.ticks = element_blank(),
      axis.title = element_blank()
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
  transform = \(x) x - 273.15
)

temp_df_10k <- raster_to_df(
  temp_10k,
  value_name = "max_tmp"
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


############################################
# Combine maps
############################################
map_dwd + map_10k + map_euro + plot_annotation(tag_levels = "A")

map_10k + map_euro + plot_annotation(tag_levels = "A")
ggsave(
  filename = "output/ger_10keur.tif",
  scale = 3,
  width = 90,
  height = 45,
  units = "mm",
  dpi = 500
)
