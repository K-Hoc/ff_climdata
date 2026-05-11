# A high-resolution daily climate time series for Germany (1981-2100) — code directory overview

This folder contains the scripts, data snapshots, and helpers used to create and process 1 km climate clusters for Germany.

## Current status (2026-05-07)

- Primary workflow: RMarkdown + R + Python scripts for preprocessing, clustering, bias correction and data extraction.
- Main outputs and snapshots are kept under `clustered/`, `tif/` and `output/`.

## Active (current) files

- `01_clim_scr.Rmd` — input preparation and climate scrubbing (preprocessing).
- `02_cluster5-10k.py` — clustering script (produces clusterings for multiple `k` values).
- `03_post_clustering.Rmd` — post-clustering analyses and checks.
- `04_Centoid_LatLon.Rmd` — compute centroids and representative lat/lon for clusters.
- `05_tiff_creation.Rmd` — produce GeoTIFFs for visualization.
- `06_bias_handling.Rmd` — compute bias/correction tables between models and reference climatology.
- `07_getClimData.R` — extract per-cluster time series from the Spark/SQL backend (long-running).
- `08_Evaluate_clim_dat.R` — QA and light evaluation of extracted datasets.
- `2_work.Rproj` — RStudio project file.
- `map_fig_creation.R` — helper for map/figure creation.

## Folders

- `bias_tbl/` — bias tables and aggregated summaries per model.
- `clim_dbs/` — helper scripts for database handling and sorting (contains `sort.py`, `sort_sqlite.sh`).
- `clustered/` — cluster outputs and per-cluster climate CSVs (multiple `k` values and snapshots such as `20250513/`).
- `gis/` — spatial resources and the QGIS project (`germany_1km.qgz`).
- `output/` — miscellaneous outputs and intermediate files.
- `tif/` — generated GeoTIFFs for mapping and visualization.

## Quick workflow (recommended order)

1. Prepare and scrub inputs: `01_clim_scr.Rmd`.
2. Run clustering: `02_cluster5-10k.py`.
3. Post-process results and select centroids: `03_post_clustering.Rmd`, `04_Centoid_LatLon.Rmd`.
4. Create spatial products: `05_tiff_creation.Rmd`.
5. Compute bias corrections: `06_bias_handling.Rmd`.
6. Extract per-cluster time series: `07_getClimData.R` (requires Spark/SQL access and substantial disk space).
7. Evaluate extracted datasets: `08_Evaluate_clim_dat.R`.

## Notes

- `07_getClimData.R` is long-running and produces large outputs; test with small subsets before full runs.
- Use `clim_dbs/sort.py` and `clim_dbs/sort_sqlite.sh` to organize DB exports when needed.
- `clustered/` contains multiple k-level results (e.g. `k5000_*`, `k10000_*`) and the baseline `multi_year_mean_climate1981_2010.csv`.
