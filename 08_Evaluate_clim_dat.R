# ---- Evaluate climate data ----
library(RSQLite)
library(tidyverse)

base_path <- "/data/public/data/climatedata/germany_1km_res/2_work"

db.conn <- dbConnect(
  RSQLite::SQLite(),
  dbname = file.path(base_path, "clim_dbs", "climate_db_ICHEC-EC-EARTH_rcp_8_5_v4.sqlite")
)

tabs <- dbListTables(db.conn)


## what to extract: first 10 and last 10 years
tab <- tabs[1]
ctab <- dbReadTable(db.conn, tab)
summary(ctab)


ctab_agg <- list()

i <- 1
for (tab in tabs) {
  ctab <- dbReadTable(db.conn, tab)
  
  ctab_ext <- rbind(
    ctab %>% filter(year < 2017) %>% group_by(lat, lon, cluster) %>% 
      summarise(min_temp = mean(min_temp), max_temp = mean(max_temp), rad = mean(rad), vpd = mean(vpd),
                prec = sum(prec) / n_distinct(year),
                .groups = "drop" # Drop all grouping after summarising
      ) %>%  mutate(type = "first_years"),
    ctab %>% filter(year > 2089) %>% group_by(lat, lon, cluster) %>% 
      summarise(min_temp = mean(min_temp), max_temp = mean(max_temp), rad = mean(rad), vpd = mean(vpd),
                prec = sum(prec) / n_distinct(year),
                .groups = "drop" # Drop all grouping after summarising
      ) %>%     mutate(type = "last_years"),
    
    
    ctab %>% filter(year == 2024 & month==7 & day == 6) %>% 
      select(lat, lon, cluster, min_temp, max_temp, rad, vpd, prec) %>% mutate(type = "2024_07_06"),
    
    ctab %>% filter(year == 2043 & month==12 & day == 6) %>% 
      select(lat, lon, cluster, min_temp, max_temp, rad, vpd, prec) %>% mutate(type = "2043_12_06")
  )
  
  ctab_agg [[ tab ]] <- ctab_ext %>% mutate(table_name = tab)
  i <- i + 1
  if (i %% 100 == 0) print(i)
  
}

tabagg <- bind_rows(ctab_agg)
dbDisconnect(db.conn, tab)

summary(tabagg)

ggplot(tabagg, aes(x=lon, y=lat, color=max_temp ) ) + 
  geom_point() + facet_wrap(~type, scales="free") + scale_color_viridis_c(option="turbo")


library(terra)
r <- rast("tif/10k_clim_cl.tif")
plot(r, "cluster")

#writeRaster(r[["cluster"]], paste0(base_path, "clusters.tif"))

clusters <- r
plot(clusters)
clusters <- r[["cluster"]]
plot(clusters == 9999)
plot(clusters)

dat <- tabagg %>% filter(type == "first_years")

#r <- classify(clusters, rcl = dat)

rc <- subst(clusters, from = dat$cluster, to = dat$max_temp )
plot(rc)

rc <- subst(clusters, from = dat$cluster, to = dat$prec )
plot(rc)

tabagg$max_temp[ clusters[] ]
r<- clusters
setValues(r, tabagg[tabagg$type=="first_years",]$max_temp[ clusters[] ])
plot(r)

# ----- Analysis K -----
# Load raster
clust_raster <- rast("tif/10k_clim_cl.tif") #~/NAS/ff_climate_cluster_old//tif/reference_raster.tif")
#plot(clust_raster)

clust_raster <- clust_raster[["cluster"]]
plot(clust_raster) # Shows clustering in GER

# Data frame
df <- dat

# --- Create lookup matrix for classify() ---
# Must be a 2-column matrix: from -> to
lookup_mat <- as.matrix(df %>% select("cluster", "prec"))
head(lookup_mat)

# --- Classify raster: replace cluster IDs with precipitation values ---
clust_raster_prec <- classify(clust_raster, rcl = lookup_mat)

# --- Verify result ---
plot(clust_raster_prec, main = "Precipitation by Cluster (classified)")

# --- Optional: check metadata integrity ---
print(crs(clust_raster_prec))
print(ext(clust_raster_prec))
print(res(clust_raster_prec))

# --- Create a mask for a single cluster of interest ---
cluster_of_interest <- 9999

cluster_mask <- clust_raster
values(cluster_mask) <- ifelse(values(clust_raster) == cluster_of_interest, 1, NA)

# --- Plot overlay ---
plot(clust_raster_prec, main = "All clusters (background)")
plot(cluster_mask, col = "red", add = TRUE)
