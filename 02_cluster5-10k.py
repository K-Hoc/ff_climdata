import argparse
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import MiniBatchKMeans
import resource
from scipy.spatial.distance import cdist

soft, hard = 300*1024**3, 500*1024**3
resource.setrlimit(resource.RLIMIT_AS, (soft, hard))

### ARGPARSE ###
# Set up argument parser
parser = argparse.ArgumentParser(description="Fing optimal number of clusters.")

# Add arguments
parser.add_argument("file", type=str, default="clim_dat.csv", help="Path to input .csv file")
#parser.add_argument("-k", type=int, default=10, help="Number of clusters.")

# Clustering function
def k_cluster(data, cluster_n):
    data_clean = data.dropna().copy()
    scaler = StandardScaler()
    data_sc = scaler.fit_transform(data_clean[["max_tmp","min_tmp","prec","rad","vpd"]])

    # MiniBatchKMeans
    kmeans = MiniBatchKMeans(
        n_clusters=cluster_n,
        #batch_size=1024,
        batch_size=50000,
        random_state=1312,
        reassignment_ratio=0.01
    )
    labels = kmeans.fit_predict(data_sc)
    
    # Find closest data point to each centoid
    centoids = kmeans.cluster_centers_
    closest_indis = []

    for cluster_id in range(cluster_n):
        cluster_mask = labels == cluster_id
        cluster_points = data_sc[cluster_mask]
        cluster_indices = data_clean.index[cluster_mask]

        # Calculate distances to centroid
        distances = cdist(cluster_points, centoids[cluster_id].reshape(1, -1))
        closest_idx = np.argmin(distances)
        closest_indis.append(cluster_indices[closest_idx])

    # Returns
    return labels, data_clean.index, kmeans, scaler, closest_indis


def main(csv_file):
    df = pd.read_csv(csv_file)
    print(df.head())

    for i in [5000, 6000, 7000, 8000, 9000, 10000, 15000]:
        try:
            print(f"starting creating {i} clusters...")
            labels, clean_indices, kmeans, scaler, closest_idx = k_cluster(
                data=df,
                cluster_n=i
            )
            df_result = df.copy()
            df_result.loc[clean_indices, "cluster"] = labels
            df_result.to_csv(f"clustered/k{i}_clim_dat.csv", index=False)
            print("Clustered dataframe saved.")

            # Save Centoids
            centoids = scaler.inverse_transform(kmeans.cluster_centers_)
            df_centoids = pd.DataFrame(centoids, columns=["max_tmp","min_tmp","prec","rad","vpd"])
            df_centoids["rep_index"] = closest_idx
            df_centoids.to_csv(f"clustered/k{i}_centoids.csv", index_label="cluster_id")
            print("Centoids saved.")

            print(f"clustering {i} done")
        except Exception as e:
            print(f"Clustering with {i} clusters failed: {e}")


if __name__ == "__main__":
    args = parser.parse_args()
    main(args.file)