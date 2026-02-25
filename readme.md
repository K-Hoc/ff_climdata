# Germany 1 km climate clusters — repository overview

This repository contains scripts, data snapshots and helpers used to create and process 1 km climate clusters for Germany and to gather cluster-specific climate time series from model output.

Key points
- Purpose: cluster Germany into ~10k climate-representative units (1981–2010 baseline), compute bias/corrections and extract daily climate time series per cluster from model data (historical + RCP scenarios).
- Inputs: DWD-derived observational variables (temperature, radiation, vapor pressure deficit, precipitation) and climate model outputs accessed via a Spark/SQL backend.

Repository structure (top-level)
- `01_clim_scr.Rmd` — exploratory/preprocessing RMarkdown for climate scrubbing and preparation.
- `02_cluster5-10k.py` — Python clustering script (produces clusters at various k values).
- `03_post_clustering.Rmd` / `04_Centoid_LatLon.Rmd` — post-clustering analysis: select representative points and compute centroid/lat-lon summaries.
- `05_tiff_creation.Rmd` — create spatial TIFFs from cluster results.
- `06_bias_handling.Rmd` — compute bias/correction factors between model and reference climatologies.
- `07_getClimData.R` — long-running data extraction from the Spark DB; applies bias corrections when writing cluster time series.
- `08_Evaluate_clim_dat.R` — light evaluation/QA of the extracted climate datasets.
- `clim_dat.csv`, `cluster_coords.csv` — summary CSVs used in analysis and mapping.

Folders (will be created during processing)
- `bias_tbl/` — bias tables and aggregated summaries per model (CSV files).
- `clim_dbs/` — helper scripts for creating/organising SQLite databases; contains `sort.py` and `sort_sqlite.sh`.
- `clustered/` — cluster outputs and per-cluster climate CSVs. Contains `k5000_...` to `k15000_...` variants and a `multi_year_mean_climate1981_2010.csv` baseline. Also contains dated snapshots (e.g. `20250513/`).
- `output/` — miscellaneous outputs and interim files.
- `tif/` — generated GeoTIFFs for spatial visualization.

## Notes on data and processing
- Clustering: uses DWD-derived climate variables to create spatial clusters; representative points and centroid metadata are produced for each cluster.
- Bias handling: mean climate differences (30-year baseline) are used to compute correction factors applied during extraction (temperatures typically adjusted additively; precipitation, vpd, radiation multiplicatively).
- Extraction: `07_getClimData.R` queries the Spark/SQL backend to build per-cluster time series (1981–2100). The extraction can be long-running and may require restarts; outputs are large (multiple GB per DB file).

Quick pointers
- If you want to re-run clustering: inspect and run `02_cluster5-10k.py` and then the post-clustering notebooks for centroid selection.
- For bias calculation and correction: see `06_bias_handling.Rmd` and files in `bias_tbl/`.
- To (re)run extraction: `07_getClimData.R` — verify DB access, available disk space, and consider splitting work into manageable chunks.

### Contact / authorship

**Authors**: Kilian Hochholzer, Christina Dollinger, Marc Grünig, Rupert Seidl, Werner Rammer

- Maintainer: repository owner (check git history) — open an issue or contact the project owner for access details to the Spark DB and runtimes.

### Citation

@article{hochholzer2026climatecluster,
  title = {},
  author = {},
  journal = {Journal / Archive},
  year = {2026},
  doi = {INSERT_DOI_HERE},
  url = {https://github.com/your-repo}
}