#!/usr/bin/env Rscript
# Unsupervised clustering for sample point selection
# This script performs K-means clustering to identify natural groupings
# in the data and suggests sampling locations for each cluster

suppressPackageStartupMessages({
    library(sits)
    library(sf)
    library(terra)
    library(cluster)
})

cat("========================================\n")
cat("Unsupervised Clustering for Sample Selection\n")
cat("========================================\n\n")

# ==============================================================================
# Configuration
# ==============================================================================

DATA_DIR <- "data/planetscope_mosaicked"  # Use mosaicked data
OUTPUT_DIR <- "data/clustering_results"
CLUSTER_OUTPUT <- file.path(OUTPUT_DIR, "clusters")

# Clustering parameters
N_CLUSTERS <- 10  # Number of clusters (adjust based on your expected classes)
SAMPLE_SIZE <- 2000  # Number of pixels to sample for clustering (reduced for multiple tiles)
POINTS_PER_CLUSTER <- 20  # Number of sample points to extract per cluster

# Index calculation (disabled for irregular cube)
USE_INDICES <- FALSE
INDICES <- c("vegetation", "water", "soil")  # Focus on key indices for faster processing

# Memory settings
MEMSIZE <- 8
MULTICORES <- 1  # Reduced to avoid gdalcubes parallel processing issues

# ==============================================================================
# Step 1: Create cube with indices
# ==============================================================================

cat("Step 1: Creating sits cube with indices...\n")

planet_cube <- sits_cube(
    source = "PLANET",
    collection = "MOSAIC-8B",
    data_dir = DATA_DIR,
    parse_info = c("date", "tile", "X1", "band"),
    delim = "_"
)

cat("  Cube created:\n")
cat("    Tiles:", nrow(planet_cube), "\n")

# Handle multiple tiles with different timelines
timeline <- sits_timeline(planet_cube)
if (is.list(timeline)) {
    # Multiple tiles with different timelines
    all_dates <- unique(unlist(timeline))
    cat("    Timeline: Multiple timelines (tiles have different dates)\n")
    cat("    Date range:", min(as.Date(all_dates)), "to", max(as.Date(all_dates)), "\n\n")

    # Select the tile with most dates for clustering
    tile_lengths <- sapply(timeline, length)
    best_tile_idx <- which.max(tile_lengths)

    cat("  NOTE: Tiles have non-overlapping dates. Selecting tile", best_tile_idx, "for clustering\n")
    cat("        (This tile has", tile_lengths[best_tile_idx], "dates)\n\n")

    planet_cube <- planet_cube[best_tile_idx, ]

    cat("  Selected tile:\n")
    cat("    Timeline:", length(sits_timeline(planet_cube)), "dates\n")
    cat("    Date range:", min(sits_timeline(planet_cube)), "to", max(sits_timeline(planet_cube)), "\n\n")
} else {
    cat("    Timeline:", length(timeline), "dates\n")
    cat("    Date range:", min(timeline), "to", max(timeline), "\n\n")
}

# Create output directory if needed
if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Regularize cube (required for sits_get_data)
cat("  Regularizing cube (required for sampling)...\n")
cat("  Using single-core processing to avoid crashes...\n")

planet_cube <- sits_regularize(
    cube = planet_cube,
    period = "P1M",  # Monthly intervals
    res = 3,  # 3m resolution
    multicores = 1,  # Single core to avoid gdalcubes crashes
    output_dir = file.path(OUTPUT_DIR, "regularized")
)

cat("  Regularization complete!\n")
cat("    Timeline:", length(sits_timeline(planet_cube)), "dates\n\n")

# Add indices if enabled
if (USE_INDICES) {
    cat("  Adding spectral indices...\n")
    source("scripts/calculate_indices.R")
    planet_cube <- add_indices(planet_cube, indices = INDICES)
    cat("  Bands/Indices:", paste(sits_bands(planet_cube), collapse = ", "), "\n\n")
}

# ==============================================================================
# Step 2: Extract random sample of pixels for clustering
# ==============================================================================

cat("Step 2: Extracting random pixel samples for clustering...\n")
cat("  Sampling", SAMPLE_SIZE, "random pixels...\n")

# Create random points across the study area
first_tile <- planet_cube[1, ]
bbox <- sits_bbox(first_tile)

# Extract bbox values (sits_bbox returns a tibble)
xmin <- bbox$xmin[1]
xmax <- bbox$xmax[1]
ymin <- bbox$ymin[1]
ymax <- bbox$ymax[1]

# Generate random points
set.seed(42)  # For reproducibility
random_points <- data.frame(
    id = 1:SAMPLE_SIZE,
    longitude = runif(SAMPLE_SIZE, xmin, xmax),
    latitude = runif(SAMPLE_SIZE, ymin, ymax)
)

# Convert to sf object
random_points_sf <- sf::st_as_sf(
    random_points,
    coords = c("longitude", "latitude"),
    crs = sf::st_crs(first_tile$crs)[[1]]
)

# Add a dummy label (required by sits_get_data)
random_points_sf$label <- "sample"

# Extract time series for random points
cat("  Extracting time series...\n")
pixel_samples <- sits_get_data(
    cube = planet_cube,
    samples = random_points_sf
)

cat("  Extracted time series for", nrow(pixel_samples), "pixels\n\n")

# ==============================================================================
# Step 3: Calculate temporal statistics for clustering
# ==============================================================================

cat("Step 3: Calculating temporal statistics for clustering...\n")

source("scripts/temporal_features.R")

# Calculate temporal features (use stats only for clustering)
pixel_features <- add_temporal_features(
    pixel_samples,
    stats = c("mean", "std", "min", "max")
)

# Extract feature matrix
feature_cols <- names(pixel_features)[grepl("_mean$|_std$|_min$|_max$",
                                             names(pixel_features))]

feature_matrix <- as.matrix(pixel_features[, feature_cols, drop = FALSE])

# Remove rows with NA values
complete_rows <- complete.cases(feature_matrix)
feature_matrix <- feature_matrix[complete_rows, ]
pixel_features <- pixel_features[complete_rows, ]

cat("  Feature matrix:", nrow(feature_matrix), "samples ×", ncol(feature_matrix), "features\n\n")

# ==============================================================================
# Step 4: Perform K-means clustering
# ==============================================================================

cat("Step 4: Performing K-means clustering...\n")
cat("  Number of clusters:", N_CLUSTERS, "\n")

# Standardize features (important for K-means)
feature_matrix_scaled <- scale(feature_matrix)

# Run K-means clustering
set.seed(42)
kmeans_result <- kmeans(
    feature_matrix_scaled,
    centers = N_CLUSTERS,
    nstart = 25,  # Multiple random starts
    iter.max = 100
)

# Add cluster labels to samples
pixel_features$cluster <- kmeans_result$cluster

cat("  Clustering complete!\n")
cat("  Cluster sizes:\n")
cluster_sizes <- table(pixel_features$cluster)
for (i in 1:N_CLUSTERS) {
    cat("    Cluster", i, ":", cluster_sizes[i], "pixels\n")
}
cat("\n")

# ==============================================================================
# Step 5: Characterize clusters using indices
# ==============================================================================

cat("Step 5: Characterizing clusters...\n\n")

# Calculate cluster centers for key bands (or indices if available)
if (USE_INDICES) {
    key_features <- c("NDVI", "NDWI", "NDRE", "EVI", "BSI", "SAVI")
} else {
    # Use raw bands for characterization
    key_features <- c("B6", "B8", "B4", "B7", "B3", "B2")  # Red, NIR, Green, RedEdge, GreenI, Blue
}

cat(sprintf("%-10s", "Cluster"))
for (feat in key_features) {
    cat(sprintf("%12s", paste0(feat, "_mean")))
}
cat("\n")
cat(strrep("-", 10 + 12 * length(key_features)), "\n")

cluster_characteristics <- list()

for (cluster_id in 1:N_CLUSTERS) {
    cluster_data <- pixel_features[pixel_features$cluster == cluster_id, ]

    cat(sprintf("%-10s", paste0("C", cluster_id)))

    characteristics <- list(cluster_id = cluster_id)

    for (feat in key_features) {
        col_name <- paste0(feat, "_mean")
        if (col_name %in% names(cluster_data)) {
            value <- mean(cluster_data[[col_name]], na.rm = TRUE)
            cat(sprintf("%12.3f", value))
            characteristics[[col_name]] <- value
        } else {
            cat(sprintf("%12s", "N/A"))
        }
    }
    cat("\n")

    cluster_characteristics[[cluster_id]] <- characteristics
}
cat("\n")

# ==============================================================================
# Step 6: Suggest likely land cover types for each cluster
# ==============================================================================

cat("Step 6: Suggested land cover types for clusters...\n\n")

if (USE_INDICES) {
    suggest_land_cover <- function(ndvi_mean, ndwi_mean, ndre_mean, bsi_mean) {
        suggestions <- c()

        # Water
        if (!is.na(ndwi_mean) && ndwi_mean > 0.3) {
            suggestions <- c(suggestions, "water")
        }

        # Forest types (high NDVI)
        if (!is.na(ndvi_mean) && ndvi_mean > 0.7) {
            if (!is.na(ndre_mean) && ndre_mean > 0.3) {
                suggestions <- c(suggestions, "natural_forest")
            } else {
                suggestions <- c(suggestions, "production_forest/agroforest")
            }
        }

        # Moderate vegetation
        if (!is.na(ndvi_mean) && ndvi_mean > 0.4 && ndvi_mean <= 0.7) {
            if (!is.na(ndwi_mean) && ndwi_mean > 0.0) {
                suggestions <- c(suggestions, "paddy/grassland")
            } else {
                suggestions <- c(suggestions, "agroforest/grassland/ladang")
            }
        }

        # Low vegetation
        if (!is.na(ndvi_mean) && ndvi_mean > 0.15 && ndvi_mean <= 0.4) {
            suggestions <- c(suggestions, "sparse_vegetation/ladang")
        }

        # Bare/built-up
        if (!is.na(ndvi_mean) && ndvi_mean <= 0.15) {
            if (!is.na(bsi_mean) && bsi_mean > 0.1) {
                suggestions <- c(suggestions, "bareland")
            } else {
                suggestions <- c(suggestions, "settlement/bareland")
            }
        }

        if (length(suggestions) == 0) {
            return("mixed/unclear")
        }

        return(paste(suggestions, collapse = " or "))
    }

    for (cluster_id in 1:N_CLUSTERS) {
        chars <- cluster_characteristics[[cluster_id]]

        suggestion <- suggest_land_cover(
            chars$NDVI_mean,
            chars$NDWI_mean,
            chars$NDRE_mean,
            chars$BSI_mean
        )

        cat("  Cluster", cluster_id, "→", suggestion, "\n")
    }
} else {
    # Using raw bands - simplified suggestion based on NIR/Red ratio
    suggest_land_cover_raw <- function(b6_mean, b8_mean, b4_mean) {
        # Calculate simple NDVI-like ratio: (NIR - Red) / (NIR + Red)
        if (!is.na(b8_mean) && !is.na(b6_mean) && (b8_mean + b6_mean) > 0) {
            ndvi_approx <- (b8_mean - b6_mean) / (b8_mean + b6_mean)

            if (ndvi_approx > 0.6) {
                return("forest/dense_vegetation")
            } else if (ndvi_approx > 0.3) {
                return("moderate_vegetation/cropland")
            } else if (ndvi_approx > 0.1) {
                return("sparse_vegetation/grassland")
            } else {
                return("bareland/settlement/water")
            }
        }
        return("unclear")
    }

    for (cluster_id in 1:N_CLUSTERS) {
        chars <- cluster_characteristics[[cluster_id]]

        suggestion <- suggest_land_cover_raw(
            chars$B6_mean,
            chars$B8_mean,
            chars$B4_mean
        )

        cat("  Cluster", cluster_id, "→", suggestion, "\n")
    }
}
cat("\n")

# ==============================================================================
# Step 7: Extract representative sample points from each cluster
# ==============================================================================

cat("Step 7: Extracting representative sample points...\n")

# Create output directory
if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
}

all_sample_points <- list()

for (cluster_id in 1:N_CLUSTERS) {
    cluster_data <- pixel_features[pixel_features$cluster == cluster_id, ]

    # Select random points from this cluster
    n_points <- min(POINTS_PER_CLUSTER, nrow(cluster_data))

    if (n_points > 0) {
        sample_indices <- sample(1:nrow(cluster_data), n_points)
        cluster_points <- cluster_data[sample_indices, ]

        # Get coordinates
        coords <- sf::st_coordinates(cluster_points)

        # Calculate suggested label
        if (USE_INDICES) {
            suggested <- suggest_land_cover(
                mean(cluster_points$NDVI_mean, na.rm = TRUE),
                mean(cluster_points$NDWI_mean, na.rm = TRUE),
                mean(cluster_points$NDRE_mean, na.rm = TRUE),
                mean(cluster_points$BSI_mean, na.rm = TRUE)
            )
        } else {
            suggested <- suggest_land_cover_raw(
                mean(cluster_points$B6_mean, na.rm = TRUE),
                mean(cluster_points$B8_mean, na.rm = TRUE),
                mean(cluster_points$B4_mean, na.rm = TRUE)
            )
        }

        # Create data frame
        points_df <- data.frame(
            cluster = cluster_id,
            longitude = coords[, "X"],
            latitude = coords[, "Y"],
            suggested_label = suggested,
            label = "",  # Empty for user to fill in
            start_date = "",
            end_date = ""
        )

        all_sample_points[[cluster_id]] <- points_df
    }
}

# Combine all sample points
sample_points_df <- do.call(rbind, all_sample_points)

cat("  Extracted", nrow(sample_points_df), "sample points\n\n")

# ==============================================================================
# Step 8: Save sample points and cluster map
# ==============================================================================

cat("Step 8: Saving results...\n")

# Save sample points as CSV
csv_file <- file.path(OUTPUT_DIR, "suggested_sample_points.csv")
write.csv(sample_points_df, csv_file, row.names = FALSE)
cat("  Sample points saved to:", csv_file, "\n")

# Convert to spatial format (GeoPackage)
sample_points_sf <- sf::st_as_sf(
    sample_points_df,
    coords = c("longitude", "latitude"),
    crs = sf::st_crs(first_tile$crs)[[1]]
)

gpkg_file <- file.path(OUTPUT_DIR, "suggested_sample_points.gpkg")
sf::st_write(sample_points_sf, gpkg_file, delete_dsn = TRUE, quiet = TRUE)
cat("  Sample points saved to:", gpkg_file, "\n\n")

# Classify the full cube using cluster assignments
cat("  Generating cluster map for full cube...\n")
cat("  (This may take a while...)\n\n")

# Create a simple classification function based on cluster centers
cluster_centers <- kmeans_result$centers

# Function to assign cluster based on nearest center
classify_pixel <- function(pixel_features, centers) {
    # Calculate distances to each center
    distances <- apply(centers, 1, function(center) {
        sqrt(sum((pixel_features - center)^2))
    })
    # Return cluster with minimum distance
    which.min(distances)
}

# Note: For full cube classification, we would need to:
# 1. Calculate indices for entire cube (already done)
# 2. Calculate temporal statistics for each pixel
# 3. Classify based on nearest cluster center
# This is computationally intensive and better done with sits_classify

cat("  NOTE: Full cluster map generation requires extensive computation.\n")
cat("  For now, use the suggested sample points to collect training data.\n")
cat("  After collecting samples, run supervised classification.\n\n")

# ==============================================================================
# Step 9: Summary and next steps
# ==============================================================================

cat("========================================\n")
cat("Clustering Complete!\n")
cat("========================================\n\n")

cat("Results:\n")
cat("  - Identified", N_CLUSTERS, "clusters in the data\n")
cat("  - Extracted", nrow(sample_points_df), "suggested sample points\n")
cat("  - Sample points saved to:", csv_file, "\n")
cat("  - GeoPackage saved to:", gpkg_file, "\n\n")

cat("Next steps:\n\n")

cat("1. Review suggested sample points:\n")
cat("   - Open in QGIS:", gpkg_file, "\n")
cat("   - Load PlanetScope imagery as background\n")
cat("   - Review 'suggested_label' field for each point\n\n")

cat("2. Field verification:\n")
cat("   - Visit locations or use high-resolution imagery\n")
cat("   - Update 'label' field with actual land cover\n")
cat("   - Add 'start_date' and 'end_date' fields\n")
cat("   - Delete points that are unclear or inaccessible\n")
cat("   - Add more points if needed for underrepresented classes\n\n")

cat("3. Create training samples:\n")
cat("   - Export updated points to CSV\n")
cat("   - Or use QGIS to digitize additional samples\n")
cat("   - Ensure at least 30-50 samples per class\n\n")

cat("4. Run supervised classification:\n")
cat("   Rscript scripts/classify_planetscope.R\n\n")

cat("Cluster characteristics saved above - review to understand\n")
cat("what each cluster might represent.\n\n")

cat("TIP: Clusters may not perfectly match your desired classes.\n")
cat("Use them as a GUIDE for sampling locations, not as final labels!\n\n")
