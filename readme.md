# Data for: A high-resolution daily climate time series data for Germany (1981-2100)

This is a computational pipeline designed to generate high-resolution (1km²) climate time series for Germany. Spatial climate data points (DWD) are clustered, and time series for each cluster created from coarse EURO-CORDEX data. This makes the coarse outputs of climate models available at a finer grid, making it more suitable for ecological applications like ecosystem modelling in iLand.

## Overview

The core objective is to bridge the gap between large-scale climate models and local-scale ecological needs. The pipeline uses K-Means clustering (via Python's `scikit-learn`) on climate variables (temperature, precipitation, radiation, VPD) resulting in groups of similar environments. Through identifying representative centroids, we can interpolate/extrapolate historical and future climate trends across the entire German territory at a 1km resolution.

## Key Features

* **Multi-scale Clustering**: Supports various cluster densities (ranging from $k=5000$ up to $k=15000$).
* **Bias Correction**: Holds a pipeline for bias correction between historical DWD observations and future climate model projections (e.g., EURO-CORDEX).
* **Spatial Products**: Generates production-ready GeoTIFFs for seamless integration into GIS software like QGIS.
* **Timeline databases**: Generates .sqlite databases holding the climate timelines that, together with reference GeoTIFF, can be used to access climate timeline for each location.

## Repository Structure

### Core Scripts & Workflows

| File | Role | Description |
| :--- | :--- | :--- |
| `01_clim_scr.Rmd` | **Preprocessing** | Scrubber and preparation of raw DWD raster data into a unified format. |
| `02_cluster5-10k.py` | **Clustering** | Clustering implementation using `MiniBatchKMeans`. |
| `03_post_clustering.Rmd`| **Analysis** | Post-clustering processing, including anomaly calculation and cluster metric evaluation. |
| `04_Centoid_LatLon.Rmd` | **Refinement** | Identification of representative latitude/longitude coordinates for each cluster centroid. |
| `05_tiff_creation.Rmd` | **Rasterization** | Generation of spatially continuous GeoTIFF files for cluster indices and parameters. |
| `06_bias_handling.Rmd` | **Correction** | Computation of bias correction factors to align future models with historical observations. |
| `07_getClimData.R` | **Extraction** | Extraction of per-cluster time series from a Spark backend. |
| `08_Evaluate_clim_dat.R` | **QA/QC** | Evaluation and quality assurance of the final extracted datasets. |

### Data & Output Organization

The workflow will create directories that are used to store intermediate and final results.

* `clustered/`: Contains cluster results for various $k$ values (e.g., `k10000_clim_dat.csv`).
* `bias_tbl/`: Stores calculated bias correction factors and aggregated historical summaries.
* `tif/`: Generated spatial products (GeoTIFF format).
* `output/`: Intermediate plots, summary tables, and extracted statistics.
* `clim_dbs/`: SQLite databases containing processed climate time series for rapid access.

## Quick Workflow

To reproduce the full pipeline, execute the scripts in the following order:

1.  **Data Preparation**: Run `01_clim_scr.Rmd` to preprocess raw raster inputs.
2.  **Clustering**: Execute `0_cluster5-10k.py` to perform K-Means clustering on the prepared climate data.
3.  **Post-Processing**: Run `03_post_clustering.Rmd` and `04_Centoid_LatLon.Rmd` to refine cluster centroids and calculate anomalies.
4.  **Spatial Mapping**: Use `05_tiff_creation.Rmd` to generate the 1km resolution raster layers.
5.  **Bias Correction Setup**: Run `06_bias_handling.Rmd` to compute necessary bias correction parameters.
6.  **Data Extraction**: Execute `07_getClimData.R` (Note: This step is resource-intensive and requires a Spark environment).
7.  **Validation**: Use `08_Evaluate_clim_dat.R` to verify the integrity of the final datasets.

## Requirements

### Software Dependencies
* **Python 3.x** (`scikit-learn`, `pandas`, `numpy`, `scipy`)
* **R (4.x)** (`terra`, `sf`, `tidyverse`, `sparklyr`, `RSQLite`, `patchwork`)
* **Apache Spark** (Required for large-scale data extraction in step 7)

### Data Dependencies
This repository requires raw climate rasters (e.g., DWD TADM/TADNMM, EURO-CORDEX). These must be placed in the appropriate `1_dataRaw` directory structure before running the pipeline.
