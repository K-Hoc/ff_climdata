### This script grabs the point_id and coordinates for all climate points from
### Spark and stores it into a .sqlite database

library(sparklyr)
library(DBI)

if (.Platform$OS.type == "windows") {
  #cPath <- "F:/Projects/FutureForest/FF_main/04_work/kilian/ff_climate_cluster"
  cPath <- "F:/Data/climatedata/germany_1km_res/2_work"
  path_dss <- "/data/dss/SVD/data/climate_database/spark_db_v3/"
} else {
  cPath <- "/data/public/Data/climatedata/germany_1km_res/2_work"
  path_dss <- "/data/dss/SVD/data/climate_database/spark_db_v3/"
  path_dss1 <- "/data/dss/SVD/data/climate_database/spark_db/"
}
cPath <- normalizePath(cPath, winslash = "/")
path_dss <- normalizePath(path_dss, winslash = "/")
path_dss1 <- normalizePath(path_dss1, winslash = "/")

# ------------- Spark config -------------------------------------------
Sys.setenv("SPARK_HOME" = "/opt/spark")
# Set memory allocation for whole local spark instance
Sys.setenv("SPARK_MEM" = "500G") #13g

# Optionally, ensure JAVA_HOME is also visible to the R session,
# though sparklyr often picks this up from Spark's environment if SPARK_HOME is set.
# Replace with your actual Java home if needed (the one you put in spark-env.sh)
Sys.setenv(JAVA_HOME = "/usr/lib/jvm/java-8-openjdk-amd64") # Or your specific path

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
config$`spark.network.timeout` <- "1200s" # 20 min timeout
config$`spark.executor.heartbeatInterval` <- "60s"
config$spark.sql.catalogImplementation <- "in-memory"
config$spark.hadoop.hive.metastore.uris <- ""  # explicitly remove Hive URI
options(java.parameters = "-Xmx456G") # "-Xmx8048m")
# ------------------ End config

# Create a .sqlit DB
point_db <- DBI::dbConnect(
  RSQLite::SQLite(),
  file.path(cPath, "clim_dbs", "point_coords.sqlite")
)
cat("Connected to .sqlite DB..\n"); flush.console()

# Create spark connection
sc <- sparklyr::spark_connect(master = "local", config = config)
cat("Spark connected...\n"); flush.console()

# Create spark table handler
spark_tbl_handler <- spark_read_parquet(
  sc,
  name = NULL,
  path = file.path(path_dss, paste0("ICHEC-EC-EARTH_historical", "/")),
  #path = file.path(path_dss1, paste0("ICHEC-EC-EARTH_historical", "/")),
  memory = TRUE
)

cat("Spark table handler created...\n"); flush.console()
cat("Gathering data\n"); flush.console()

point_res <- tryCatch({
  spark_tbl_handler %>% 
    #sparklyr::filter(year == 2005) %>% 
    sparklyr::select(point_id, x_wgs, y_wgs, x_rot, y_rot) %>%
    sparklyr::distinct() %>% 
    sparklyr::collect()
}, error = function(e) {
  cat("Error during Spark collect: ", e$message, "\n")
  flush.console()
  return(NULL)
})

cat("Data gathered. Writing to .sqlite\n"); flush.console()

DBI::dbBegin(point_db)
dbWriteTable(
  conn = point_db,
  name = "coordinates",
  value = point_res,
  overwrite = TRUE
)
DBI::dbCommit(point_db)

# ------ Disconnect ----------------------------------
cat("Disconnecting..\n"); flush.console()
sparklyr::spark_disconnect(sc)
sparklyr::spark_disconnect_all()
sc <- NULL
spark_tbl_handler <- NULL
dbDisconnect(point_db)
cat("Disconnect successfull.\n"); flush.console()