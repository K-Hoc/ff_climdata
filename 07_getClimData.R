library(tidyverse)
library(sparklyr)
library(terra)
library(sf)
library(DBI)

if (.Platform$OS.type == "windows") {
  cPath <- "F:/Data/climatedata/germany_1km_res/2_work"
  path <- "F:/Projects/FutureForest/FF_main/04_work/marc/"
  path_dss <- "/data/dss/SVD/data/climate_database/spark_db_v3/"
} else {
  cPath <- "/data/public/Data/climatedata/germany_1km_res/2_work"
  path <- "/data/public/Projects/FutureForest/FF_main/04_work/marc/"
  path_dss <- "/data/dss/SVD/data/climate_database/spark_db_v3/"
}
cPath <- normalizePath(cPath, winslash = "/")
path <- normalizePath(path, winslash = "/")
path_dss <- normalizePath(path_dss, winslash = "/")

setwd(cPath)
dfCoords <- read.csv(file = "cluster_coords.csv")
smpl_pnts <- read.csv(
  file = file.path(path, "coords_rep_cl_ger.csv")
)

# f_getPointID <- function(x, rast, ref_tab){
#   # extract the grid ID
#   lon <- x$lon
#   lat <- x$lat
# 
#   coords <- as.data.frame(cbind(lon, lat))
# 
#   point_extr <- terra::extract(rast, coords)[,2]
# 
#   na_indices <- which(is.na(point_extr))
#   if(length(na_indices) > 0) {
#     for (i in na_indices) {
#       lon_i <- lon[i]
#       lat_i <- lat[i]
#       closest_grid <- ref_tab[which.min(abs(lon_i - ref_tab$gk_x) + abs(lat_i - ref_tab$gk_y)),]
#       point_extr[i] <- as.numeric(closest_grid[1])
#     }
#   }
# 
#   return(point_extr)
# }
# f_getPointID <- function(x, ref_rast) {
#   g_gaus_krueger <- "EPSG:31467"
#   g_wgs84 <- "EPSG:4326"
#   
#   coords <- x %>% dplyr::select(lat, lon)
#   n <- nrow(coords)
#   
#   # Preallocate result vector
#   ref_pnt_vec <- rep(NA, n)
#   
#   pb <- progress::progress_bar$new(
#     format = " Processing [:bar] :percent ETA :eta",
#     total = n, clear = FALSE, width = 60
#   )
#   #cat("Start loop.. \n")
#   for (i in seq_len(n)) {
#     lat <- as.numeric(coords[i, "lat"])
#     lon <- as.numeric(coords[i, "lon"])
#     #cat("Coord: ", coord)
#     # coord <- coords[1,]
#     # 1 Transformation
#     coord <- st_sfc(st_point(c(lon, lat)), crs = g_gaus_krueger)
#     coord <- st_transform(coord, g_wgs84)
#     coord <- st_coordinates(coord)
#     # coord <- vect(matrix(c(lon, lat), ncol = 2), crs = g_gaus_krueger)
#     # coord <- project(coord, g_wgs84)
#     # coord <- crds(coord)
#     
#     # # Transform to raster CRS
#     # coord <- vect(matrix(coord, ncol = 2), crs = g_wgs84) %>% 
#     #   project(., crs(ref_rast))
#     
#     # 2 Find closest raster cell
#     cell_id <- cellFromXY(ref_rast, coord)
#     cell_cnt <- xyFromCell(ref_rast, cell_id)
#     ref_id <- terra::extract(ref_rast, cell_cnt)
#     
#     # 3 if na search nearby
#     if (is.na(ref_id[[1]])) {
#       #cat("Closest cell is NA, searching nearby...\n"); flush.console()
#       
#       # Create a buffer around point
#       p <- vect(coord, type = "points", crs = g_wgs84)
#       p_buff <- buffer(p, width = 28000) # 14 km buffer
#       
#       # Crop raster to buffer
#       cropped_r <- crop(ref_rast, p_buff)
#       
#       # Get cell IDs, coords, and values
#       cell_ids <- which(!is.na(values(cropped_r)))
#       if (length(cell_ids) == 0) {
#         warning("No valid cells found nearby.")
#         ref_id <- NA
#       } else {
#         ref_coord <- xyFromCell(cropped_r, cell_ids)
#         ref_val <- values(cropped_r)[cell_ids]
#         
#         # Compute distance from point to each valid cell
#         ddist <- sqrt((ref_coord[,1] - coord[1,1])^2 + (ref_coord[,2] - coord[1,2])^2)
#         closest_idx <- which.min(ddist)
#         
#         # Update ref_id and center coord
#         ref_id <- ref_val[closest_idx]
#         cell_cnt <- ref_coord[closest_idx,]
#       }
#     }
#     
#     # Compute distance (Eucl in meter)
#     ddist <- sqrt(sum((coord - cell_cnt)^2))
#     
#     # cat("Closest raster cell id: ", cell_id)
#     # cat(" with ref_id: ", ref_id[[1]], "\n")
#     # cat("Raster center coord: ", cell_cnt, "; Point coord: ", coord, "\n")
#     # cat("Distance to center: ", ddist, "m\n")
#     # flush.console()
#     
#     ref_pnt_vec[i] <- ref_id
#     pb$tick()
#   }
#   return(ref_pnt_vec)
# }

# x_rast <- rast(file.path(path, "clim_data", "reference_grid.tif"))
# crs(x_rast) <- "+proj=longlat +datum=WGS84 +no_defs"
# 
# # Project the raster back to Gaus-Krueger
# nx_rast <- terra::project(x_rast, "EPSG:31467")
# 
# ref_tab <- read.csv(file.path(path, "clim_data", "reference_grid_tab.csv"))
# # Transform ref_tab also to Gaus-Krueger
# ref_sf <- st_as_sf(ref_tab, coords = c("wgs_x", "wgs_y"), crs = 4326)
# ref_gk <- st_transform(ref_sf, crs = 31467)
# transformed <- st_coordinates(ref_gk)
# ref_tab$gk_x <- transformed[,1]
# ref_tab$gk_y <- transformed[,2]
# head(ref_tab)
# rm(x_rast, ref_sf, ref_gk, transformed)

# Scenarios
# future_scn <- c(
#   "ICHEC-EC-EARTH_rcp_8_5",
#   "ICHEC-EC-EARTH_rcp_4_5",
#   "ICHEC-EC-EARTH_rcp_2_6",
#   "NCC-NorESM1-M_rcp_8_5",
#   "NCC-NorESM1-M_rcp_4_5",
#   "NCC-NorESM1-M_rcp_2_6",
#   "MPI-M-MPI-ESM-LR_rcp_8_5",
#   "MPI-M-MPI-ESM-LR_rcp_4_5",
#   "MPI-M-MPI-ESM-LR_rcp_2_6"
# )
hist_scn <- c(
  "ICHEC-EC-EARTH_historical",
  "NCC-NorESM1-M_historical",
  "MPI-M-MPI-ESM-LR_historical"
)
# scenarios <- c(future_scn, hist_scn)
scenarios <- c(hist_scn)

Sys.setenv("SPARK_HOME" = "/opt/spark")
# Set memory allocation for whole local spark instance
Sys.setenv("SPARK_MEM" = "500G") #13g

# Optionally, ensure JAVA_HOME is also visible to the R session,
# though sparklyr often picks this up from Spark's environment if SPARK_HOME is set.
# Replace with your actual Java home if needed (the one you put in spark-env.sh)
Sys.setenv(JAVA_HOME = "/usr/lib/jvm/java-8-openjdk-amd64") # Or your specific path
Sys.setenv(HIVE_CONF_DIR = "")
Sys.setenv(HIVE_AUX_JARS_PATH = "")
Sys.setenv(HADOOP_CONF_DIR = "")
Sys.setenv(METASTORE_DB_TYPE = "none")

# Set driver and executor memory allocation
config <- sparklyr::spark_config()
config$`spark.driver.memory` <- "456G" #"64G" # Driver memory (for R + Spark comms)
config$`sparklyr.shell.driver-memory` <- "456G" #"48G"
config$`spark.executor.memory` <- "456G" #"100G" # Executor (worker) memory
config$`spark.driver.maxResultSize` <- "300G" #"20G" # Max size of collect() results
config$`spark.yarn.executor.memoryOverhead` <- "48G" #"6G" # JVM overhead for executor
config$sparklyr.gateway.port = 8892
config$sparklyr.gateway.start.timeout = 180
config$sparklyr.gateway.connect.timeout = 1
config$`sparklyr.cores.local` <- 50 #4
config$`spark.executor.cores` <- 50 #4
config$`spark.network.timeout` <- "2400s" # 40 min timeout
config$`spark.executor.heartbeatInterval` <- "60s"
config$spark.sql.catalogImplementation <- "in-memory"
config$spark.hadoop.hive.metastore.uris <- ""  # explicitly remove Hive URI

options(java.parameters = "-Xmx456G") # "-Xmx8048m")

f_hive_free_read_paquete <- function(sc, path, tbl_name = NULL) {
  sdf <- spark_session(sc) %>%
    invoke("read") %>%
    invoke("parquet", path)
  
  if (!is.null(tbl_name)) {
    sdf <- sparklyr::sdf_register(sdf, tbl_name)
  }
  
  return(sdf)
}
models <- c("ICHEC-EC-EARTH", "MPI-M-MPI-ESM-LR", "NCC-NorESM1-M")

for (scn in scenarios) {
  # scn <- scenarios[2]
  cat(scn, "\n")
  flush.console()
  if (grepl("historical", scn)) {
    timesteps <- c("1981-2005")
  } else {
    timesteps <- c("2006-2030", "2031-2050", "2051-2070", "2071-2090", "2091-2100")
    #timesteps <- c("2006-2100")
  }
  
  model_nm <- models[sapply(models, function(m) grepl(m,scn))]
  if (length(model_nm) == 0) {
    stop("unknown model found in scenario string")
  }
  df_bias <- read_csv(file.path(cPath,"bias_tbl",paste0(model_nm,"_bias.csv")))
  pnt_id <- unique(df_bias$ref_point)
  # Create a .sqlit DB
  clim_db <- DBI::dbConnect(
    RSQLite::SQLite(),
    file.path(cPath, "clim_dbs", paste0("climate_db_", scn, "_v4.sqlite"))
  )
  cat("Connected to .sqlite DB..\n")
  flush.console()
  
  # If spark connection is active (which it should not be) disconnect
  if (exists("sc") && !is.null(sc)) {
    spark_disconnect(sc)
  }
  
  # Spark connection
  sc <- sparklyr::spark_connect(master = "local", config = config)
  cat("Spark connected...\n")
  flush.console()
  
  # Spark handler
  try({
    spark_session(sc) %>%
      invoke("catalog") %>%
      invoke("dropTempView", "climate")
    },
    silent = TRUE
  )
 
  # spark_tbl_handler <- spark_read_parquet(
  #   sc,
  #   name = NULL,
  #   path = file.path(path_dss, paste0(scn, "/")),
  #   memory = TRUE
  # )
  spark_tbl_handler <- f_hive_free_read_paquete(
    sc = sc,
    path = file.path(path_dss, paste0(scn, "/")),
    tbl_name = "climate"
  )
  
  cat("Spark table handler created...\n")
  flush.console()
  
  #clim_tab_list <- list()
  for (r in seq_along(timesteps)) {
    #r <- 1
    # define years
    years <- if (grepl("historical", scn)) {
      1981:2005
    } else {
      unlist(case_when(
        timesteps[r] == "2006-2030" ~ list(2006:2030),
        timesteps[r] == "2031-2050" ~ list(2031:2050),
        timesteps[r] == "2051-2070" ~ list(2051:2070),
        timesteps[r] == "2071-2090" ~ list(2071:2090),
        timesteps[r] == "2091-2100" ~ list(2091:2100)
      ))
      # Unlist to get the sequence of years
      # years <- unlist(years)
      #years <- c(2006:2100)
    }
    
    cat("Gathering for years: ", years, "\n")
    flush.console()
    
    clim_res <- tryCatch({
      #spark_tbl_handler %>% 
      tbl(sc, "climate") %>% 
        sparklyr::filter(point_id %in% pnt_id) %>% 
        sparklyr::filter(year %in% years) %>% 
        sparklyr::select(point_id, year, month, day, min_temp, max_temp, prec, rad, vpd) %>%
        sparklyr::distinct() %>% 
        sparklyr::collect()
    }, error = function(e) {
      cat("Error during Spark collect: ", e$message, "\n")
      flush.console()
      return(NULL)
    })
    
    if (is.null(clim_res)) {
      next
    }
    # clim_res <- spark_tbl_handler %>% 
    #   sparklyr::filter(point_id %in% pnt_id) %>% 
    #   sparklyr::filter(year %in% years) %>% 
    #   sparklyr::select(point_id, year, month, day, min_temp, max_temp, prec, rad, vpd) %>%
    #   sparklyr::distinct() %>% 
    #   sparklyr::collect()
    
    cat("Data gathered. Writing to .sqlite\n")
    flush.console()
    
    # Loop through all point ids
    #for (i in 1:length(pnt_id)) {
    for (i in df_bias$cluster) {
      # i <- df_bias$cluster[1]
      # Point id of cluster
      #focal_pnt <- pnt_id[i]
      focal_pnt <- i
      cat("Cluster ", focal_pnt, "\n"); flush.console()
      # cat("Point ", focal_pnt,"(",i," / ", length(pnt_id),")", "\n")
      # flush.console()
      # clim_tab_out_point <- clim_res %>% filter(point_id == focal_pnt)
      
      # Bias correction
      clim_tab_out_point <- inner_join(
        x = clim_res,
        y = df_bias %>% filter(cluster == focal_pnt),
        by = join_by(point_id == ref_point)
      ) %>% mutate(
        min_temp = min_temp + min_tmp_bias,
        max_temp = max_temp + max_tmp_bias,
        prec = prec * prec_bias,
        vpd = vpd * vpd_bias,
        rad = rad * rad_bias
      ) %>% dplyr::select(
        -ends_with("bias")
      )
      cat("bias corrected\n"); flush.console()
      # Ping spark to keep connection
      #try(sparklyr::sdf_nrow(spark_tbl_handler), silent = TRUE)
      
      #cat("writing point ", focal_pnt, " to .sqlite\n")
      #flush.console()
      
      # tbl_name <- paste0(scn, "_point", focal_pnt)
      tbl_name <- paste0(scn, "_clst_", focal_pnt)
      # Check whether table exists
      if (!dbExistsTable(conn = clim_db, name = tbl_name)) {
        cat("dbExistsTable == false\n"); flush.console()
        dbWriteTable(
          conn = clim_db,
          name = tbl_name,
          value = clim_tab_out_point[0,]
        )
      }
      
      DBI::dbBegin(clim_db)
      # write to sqlite db
      dbWriteTable(
        conn = clim_db,
        name = tbl_name, #paste0(scn, "_point", focal_pnt),
        value = clim_tab_out_point,
        append = TRUE
        #overwrite = TRUE
      )
      DBI::dbCommit(clim_db)
    }
    rm(clim_res)
    gc()
  }
  # Finally
  cat("Disconnecting..\n")
  flush.console()
  
  sparklyr::spark_disconnect(sc)
  sparklyr::spark_disconnect_all()
  sc <- NULL
  spark_tbl_handler <- NULL
  dbDisconnect(clim_db)
  
  cat("Disconnect successfull.\n")
  flush.console()
}
