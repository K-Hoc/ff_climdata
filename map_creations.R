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

############################################
# Global settings
############################################
CRS_WGS84 <- "EPSG:4326"
CRS_GK3   <- "EPSG:31467"


############################################
# Helper functions
############################################

load_country <- function(name, crs = CRS_WGS84) {
  ne_countries(
    country = name,
    scale = "medium",
    returnclass = "sf"
  ) |>
    st_transform(crs)
}

crop_mask <- function(r, country_sf) {
  v <- vect(country_sf)
  r |>
    crop(v, snap = "out") |>
    mask(v)
}

fix_and_project_raster <- function(
    r,
    country_sf,
    src_crs,
    dst_crs = CRS_WGS84,
    method = "bilinear"
) {
  crs(r) <- src_crs
  country_src <- vect(country_sf) |> project(src_crs)
  
  r |>
    crop(country_src, snap = "out") |>
    mask(country_src) |>
    project(dst_crs, method = method)
}

raster_to_df <- function(r, value_name = "value", transform = identity) {
  as.data.frame(r, xy = TRUE, na.rm = TRUE) |>
    rename(!!value_name := 3) |>
    mutate(!!value_name := transform(.data[[value_name]]))
}

compute_hillshade <- function(dem,
                              crs_metric = CRS_GK3,
                              crs_out = CRS_WGS84) {
  dem_m <- project(dem, crs_metric)
  slope  <- terrain(dem_m, "slope", unit = "radians")
  aspect <- terrain(dem_m, "aspect", unit = "radians")
  shade(slope, aspect) |> project(crs_out)
}

plot_temperature_map <- function(
    temp_df,
    hill_df,
    country_sf,
    osm_bg,
    title
) {
  bbox <- st_bbox(country_sf)
  
  ggplot() +
    annotation_spatial(osm_bg) +
    
    geom_raster(
      data = hill_df,
      aes(x = x, y = y, fill = hillshade),
      alpha = 0.4
    ) +
    scale_fill_gradient(
      low = "black",
      high = "white",
      guide = "none"
    ) +
    
    ggnewscale::new_scale_fill() +
    
    geom_raster(
      data = temp_df,
      aes(x = x, y = y, fill = temp),
      alpha = 0.8
    ) +
    scale_fill_viridis_c(name = "Temperature (°C)") +
    
    geom_sf(
      data = country_sf,
      fill = NA,
      color = "black",
      linewidth = 0.8
    ) +
    
    annotation_north_arrow(
      location = "tl",
      which_north = "true",
      pad_x = unit(0.35, "cm"),
      pad_y = unit(0.35, "cm"),
      height = unit(1.2, "cm"),
      width = unit(1, "cm"),
      style = north_arrow_orienteering
    ) +
    
    coord_sf(
      xlim = bbox[c("xmin", "xmax")],
      ylim = bbox[c("ymin", "ymax")],
      expand = FALSE
    ) +
    
    labs(title = title) +
    theme_minimal() +
    theme(
      legend.position = "none",
      panel.grid      = element_blank(),
      axis.text       = element_blank(),
      axis.ticks      = element_blank(),
      axis.title      = element_blank()
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

# EURO‑CORDEX (already WGS84)
temp_euro <- crop_mask(temp_euro_raw, country)

# DWD (wrong CRS → fix, crop, reproject)
temp_dwd <- fix_and_project_raster(
  r = temp_dwd_raw,
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

#------------------------------------------------
# Hillshade
#------------------------------------------------
dem <- get_elev_raster(
  locations = country,
  z = 6,
  clip = "locations"
) |> rast()

hill <- compute_hillshade(dem)

hill_df <- raster_to_df(
  hill,
  value_name = "hillshade"
)

#------------------------------------------------
# OpenStreetMap basemap (FIXED)
#------------------------------------------------
osm_bg <- osm.raster(
  x = country,
  zoom = 6,
  type = "osm"
)


############################################
# Maps
############################################

map_dwd <- plot_temperature_map(
  temp_df = temp_df_dwd,
  hill_df = hill_df,
  country_sf = country,
  osm_bg = osm_bg,
  title = "Temperature: 1 km resolution"
)

map_euro <- plot_temperature_map(
  temp_df = temp_df_euro,
  hill_df = hill_df,
  country_sf = country,
  osm_bg = osm_bg,
  title = "Temperature: 12 km resolution"
)

############################################
# Combine maps
############################################
map_dwd + map_euro + plot_annotation(tag_levels = "A")

# add save
ggsave(
  filename = "output/ger_1v12km.tif",
  scale = 4,
  width = 90,
  height = 45,
  units = "mm",
  dpi = 500
)
