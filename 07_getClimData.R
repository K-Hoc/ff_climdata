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

# Scenarios
future_scn <- c(
  "ICHEC-EC-EARTH_rcp_8_5",
  "ICHEC-EC-EARTH_rcp_4_5",
  "ICHEC-EC-EARTH_rcp_2_6",
  "NCC-NorESM1-M_rcp_8_5",
  "NCC-NorESM1-M_rcp_4_5",
  "NCC-NorESM1-M_rcp_2_6",
  "MPI-M-MPI-ESM-LR_rcp_8_5",
  "MPI-M-MPI-ESM-LR_rcp_4_5",
  "MPI-M-MPI-ESM-LR_rcp_2_6"
)
hist_scn <- c(
  "ICHEC-EC-EARTH_historical",
  "NCC-NorESM1-M_historical",
  "MPI-M-MPI-ESM-LR_historical"
)
scenarios <- c(future_scn, hist_scn)
# scenarios <- c(hist_scn)

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
    }
    
    cat("Gathering for years: ", years, "\n")
    flush.console()
    
    clim_res <- tryCatch({
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

    
    cat("Data gathered. Writing to .sqlite\n")
    flush.console()
    
    # Loop through all point ids
    for (i in df_bias$cluster) {
      # i <- df_bias$cluster[1]
      # Point id of cluster
      #focal_pnt <- pnt_id[i]
      focal_pnt <- i
      cat("Cluster ", focal_pnt, "\n"); flush.console()
      
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
