#!/usr/bin/env Rscript
# Simple unsupervised clustering without sits regularization
# Works directly with raster files using terra

suppressPackageStartupMessages({
    library(terra)
    library(sf)
    library(cluster)
})

cat("========================================\n")
cat("Simple Clustering for Sample Selection\n")
cat("========================================\n\n")

# Configuration
DATA_DIR <- "data/planetscope_mosaicked"
OUTPUT_DIR <- "data/clustering_results"
N_CLUSTERS <- 10
SAMPLE_SIZE <- 2000
POINTS_PER_CLUSTER <- 20

# Create output directory
if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
}

cat("Step 1: Loading raster data...\n")

# Get all B1 files to identify dates
files_b1 <- list.files(DATA_DIR, pattern = "^[0-9]{8}_.*_B1\\.tif$", full.names = TRUE)
dates <- sub("^.*/([0-9]{8})_.*", "\\1", files_b1)
unique_dates <- unique(dates)
unique_dates <- sort(unique_dates)

cat("  Found", length(unique_dates), "dates\n")
cat("  Date range:", unique_dates[1], "to", unique_dates[length(unique_dates)], "\n\n")

# Load first date to get extent
cat("Step 2: Sampling random points...\n")
first_raster <- rast(files_b1[1])
extent_bbox <- ext(first_raster)

# Generate random points
set.seed(42)
random_x <- runif(SAMPLE_SIZE, extent_bbox[1], extent_bbox[2])
random_y <- runif(SAMPLE_SIZE, extent_bbox[3], extent_bbox[4])
random_points <- vect(data.frame(x = random_x, y = random_y), geom = c("x", "y"), crs = crs(first_raster))

cat("  Generated", SAMPLE_SIZE, "random sample points\n\n")

# Extract values for all bands and all dates
cat("Step 3: Extracting values from all dates...\n")

all_values <- NULL

for (date in unique_dates) {
    cat("  Processing", date, "...\n")

    # Load all bands for this date
    band_files <- list.files(DATA_DIR,
                             pattern = paste0("^", date, "_.*_B[1-8]\\.tif$"),
                             full.names = TRUE)

    if (length(band_files) > 0) {
        # Load as multi-band raster
        date_raster <- rast(band_files)

        # Extract values
        date_values <- extract(date_raster, random_points, ID = FALSE)

        # Add to collection
        if (is.null(all_values)) {
            all_values <- date_values
        } else {
            all_values <- cbind(all_values, date_values)
        }
    }
}

cat("\n  Extracted values:", nrow(all_values), "points ×", ncol(all_values), "features\n\n")

# Calculate temporal statistics
cat("Step 4: Calculating temporal statistics...\n")

# Group by bands (every 19 columns is one band across time)
n_dates <- length(unique_dates)
n_bands <- 8

feature_matrix <- NULL

for (b in 1:n_bands) {
    # Get all time steps for this band
    band_cols <- seq(b, ncol(all_values), by = n_bands)
    band_data <- all_values[, band_cols]

    # Calculate statistics
    band_mean <- rowMeans(band_data, na.rm = TRUE)
    band_std <- apply(band_data, 1, sd, na.rm = TRUE)
    band_min <- apply(band_data, 1, min, na.rm = TRUE)
    band_max <- apply(band_data, 1, max, na.rm = TRUE)

    # Combine
    band_features <- cbind(band_mean, band_std, band_min, band_max)
    colnames(band_features) <- paste0("B", b, "_", c("mean", "std", "min", "max"))

    if (is.null(feature_matrix)) {
        feature_matrix <- band_features
    } else {
        feature_matrix <- cbind(feature_matrix, band_features)
    }
}

# Remove NA rows
complete_rows <- complete.cases(feature_matrix)
feature_matrix <- feature_matrix[complete_rows, ]
valid_points <- random_points[complete_rows]

cat("  Feature matrix:", nrow(feature_matrix), "samples ×", ncol(feature_matrix), "features\n\n")

# Perform K-means clustering
cat("Step 5: Performing K-means clustering...\n")
cat("  Number of clusters:", N_CLUSTERS, "\n")

# Standardize features
feature_matrix_scaled <- scale(feature_matrix)

# Run K-means
set.seed(42)
kmeans_result <- kmeans(
    feature_matrix_scaled,
    centers = N_CLUSTERS,
    nstart = 25,
    iter.max = 100
)

cat("  Clustering complete!\n")
cat("  Cluster sizes:\n")
cluster_sizes <- table(kmeans_result$cluster)
for (i in 1:N_CLUSTERS) {
    cat("    Cluster", i, ":", cluster_sizes[i], "pixels\n")
}
cat("\n")

# Characterize clusters
cat("Step 6: Characterizing clusters...\n\n")

# Calculate NDVI-like ratio: (B8 - B6) / (B8 + B6)
b6_mean <- feature_matrix[, "B6_mean"]
b8_mean <- feature_matrix[, "B8_mean"]
ndvi_approx <- (b8_mean - b6_mean) / (b8_mean + b6_mean)

# Show cluster characteristics
cat(sprintf("%-10s %12s %12s %12s %12s\n", "Cluster", "B6_mean", "B8_mean", "NDVI_approx", "Type"))
cat(strrep("-", 70), "\n")

cluster_chars <- list()

for (i in 1:N_CLUSTERS) {
    cluster_mask <- kmeans_result$cluster == i
    b6_avg <- mean(b6_mean[cluster_mask], na.rm = TRUE)
    b8_avg <- mean(b8_mean[cluster_mask], na.rm = TRUE)
    ndvi_avg <- mean(ndvi_approx[cluster_mask], na.rm = TRUE)

    # Suggest land cover type
    if (ndvi_avg > 0.6) {
        type <- "forest/dense_veg"
    } else if (ndvi_avg > 0.3) {
        type <- "moderate_veg"
    } else if (ndvi_avg > 0.1) {
        type <- "sparse_veg"
    } else {
        type <- "bare/water/built"
    }

    cluster_chars[[i]] <- list(
        b6_mean = b6_avg,
        b8_mean = b8_avg,
        ndvi = ndvi_avg,
        type = type
    )

    cat(sprintf("%-10s %12.1f %12.1f %12.3f %12s\n",
                paste0("C", i), b6_avg, b8_avg, ndvi_avg, type))
}
cat("\n")

# Extract sample points from each cluster
cat("Step 7: Extracting representative sample points...\n")

all_sample_points <- list()

for (i in 1:N_CLUSTERS) {
    cluster_mask <- kmeans_result$cluster == i
    cluster_points <- valid_points[cluster_mask]

    # Sample random points from this cluster
    n_points <- min(POINTS_PER_CLUSTER, sum(cluster_mask))

    if (n_points > 0) {
        sample_idx <- sample(which(cluster_mask), n_points)
        sampled_points <- valid_points[sample_idx]

        # Get coordinates
        coords <- crds(sampled_points)

        # Create data frame
        points_df <- data.frame(
            cluster = i,
            longitude = coords[, 1],
            latitude = coords[, 2],
            suggested_label = cluster_chars[[i]]$type,
            label = "",
            start_date = "",
            end_date = ""
        )

        all_sample_points[[i]] <- points_df
    }
}

# Combine all sample points
sample_points_df <- do.call(rbind, all_sample_points)

cat("  Extracted", nrow(sample_points_df), "sample points\n\n")

# Save results
cat("Step 8: Saving results...\n")

# Save as CSV
csv_file <- file.path(OUTPUT_DIR, "suggested_sample_points.csv")
write.csv(sample_points_df, csv_file, row.names = FALSE)
cat("  Sample points saved to:", csv_file, "\n")

# Save as GeoPackage
sample_points_sf <- st_as_sf(
    sample_points_df,
    coords = c("longitude", "latitude"),
    crs = st_crs(crs(first_raster))
)

gpkg_file <- file.path(OUTPUT_DIR, "suggested_sample_points.gpkg")
st_write(sample_points_sf, gpkg_file, delete_dsn = TRUE, quiet = TRUE)
cat("  Sample points saved to:", gpkg_file, "\n\n")

# Summary
cat("========================================\n")
cat("Clustering Complete!\n")
cat("========================================\n\n")

cat("Results:\n")
cat("  - Identified", N_CLUSTERS, "clusters\n")
cat("  - Extracted", nrow(sample_points_df), "suggested sample points\n")
cat("  - Sample points saved to:", csv_file, "\n")
cat("  - GeoPackage saved to:", gpkg_file, "\n\n")

cat("Next steps:\n")
cat("1. Open in QGIS:", gpkg_file, "\n")
cat("2. Review suggested_label field for each point\n")
cat("3. Update 'label' field with actual land cover\n")
cat("4. Add start_date and end_date\n")
cat("5. Use for supervised classification\n\n")
