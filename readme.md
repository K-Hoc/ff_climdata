# Clusterin of Germany and climate data gathering
---
The scripts in this directory perform a clustering and gathering of climate data from a spark database. During the first clustering step, climate data (1981-2010) is used to devide Germany in 10 000 clusters. In the secord step for each cluster climate data from 3 different climate models and 3 climate scenarios are gathered (for each day ranging from 01.01.1981 till 31.12.2100).
## Clustering Germany using climate data
Data from the DWD (German Weather Service) is used to create the clusters (maximum temperature, minimum temperature, global radiation, vapour pressure deficit - vpd).

Done in scripts:
- 01_clim_scr.Rmd
- 02_cluster5-10k.py
## Post clustering processing
### Deviation of points from cluster
Here the clustered climate data is processed, meaning the deviation from each point towards the centoid is calculated and a representative datapoint for each cluster is chosen. In the end a .csv file is created containing the information about the cluster centre and the representative plot.

Done in scripts:
-  03_Centoids_LatLon.Rmd
### Building reference to climate point ids
The climate data works with point ids, which have also been used in the previous work for the 14 km² climate data. So the challenge is to map the coordinates of these 14 km² points to the 1 km² points and calculate the difference from each 1 km² to the 14 km² cell. In a first step all point_ids and coordinates for all climate point are gathered from the Spark database and stored in the point_coords.sqlite file. The point ids are used by the climate models as location identifiers.

The resolution of the climate models are not at a 1x1 km scale, so adjustments need to be made to even match the 10k clusters. Goal of this is for each cluster to have its own climate timeline. Correction is done in a few steps:
1. Gathering 30 year periods of climate data and calculating a mean (1981-2010). Here the difficulty is that in the modelled climate, historic data ranges from 1980-2005, so that the last 5 years need to be taken from each of the 3 climate scenarios (2.6, 4.5, 8.5) and all of the 3 climate models.
2. Calculating a correction factor for every cluster (10k correction factors)

Scripts:
- 04_coord_ref.R
- 06_bias_handling.Rmd
## Gathering climate data from climate models
Here for every cluster (10k) the climate data is gathered from the Spark db, resulting in 12 .sqlit files with 3 having around 8 GB and the other 9 around 33 GB each. During the data gathering the bias calculated in the previous step is used to change the climate values to be more cluster specific.
For temperature (max_temp, min_temp), the temperature curve was changed (using addition - so adding the bias factor to the temperature), precipitation, vpd and rad were multiplied with the bias factor.

The script runs for about 2 Weeks (it might abort and needs to be restarted), but there might be ways to improve on this.

Script:
- 07_getClimData.R
## Small evaluation
Some evaluations on the .sqlit files

Script:
08_Evaluate_clim_dat.R