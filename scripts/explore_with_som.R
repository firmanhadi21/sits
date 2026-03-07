#!/usr/bin/env Rscript
# Self-Organizing Maps (SOM) for exploratory analysis
# SOM is excellent for visualizing patterns in time series data
# and identifying representative samples for each pattern

suppressPackageStartupMessages({
    library(sits)
    library(sf)
})

cat("========================================\n")
cat("SOM-based Exploratory Analysis\n")
cat("========================================\n\n")

# ==============================================================================
# Configuration
# ==============================================================================

DATA_DIR <- "data/planetscope_processed"
OUTPUT_DIR <- "data/som_results"

# SOM parameters
SOM_GRID_X <- 5  # Grid dimensions (5x5 = 25 neurons)
SOM_GRID_Y <- 5
SAMPLE_SIZE <- 2000  # Pixels to sample for SOM training
POINTS_PER_NEURON <- 5  # Sample points per SOM neuron

# Index configuration
USE_INDICES <- TRUE
INDICES <- c("vegetation", "water")  # Focus on key indices for faster processing

# ==============================================================================
# Step 1: Create cube and extract samples
# ==============================================================================

cat("Step 1: Creating cube and extracting pixel samples...\n")

planet_cube <- sits_cube(
    source = "PLANET",
    collection = "MOSAIC-8B",
    data_dir = DATA_DIR,
    parse_info = c("date", "X1", "X2", "tile", "X3", "X4", "X5", "X6", "X7", "X8", "band"),
    delim = "_"
)

# Add indices
if (USE_INDICES) {
    source("scripts/calculate_indices.R")
    planet_cube <- add_indices(planet_cube, indices = INDICES)
}

cat("  Sampling", SAMPLE_SIZE, "random pixels...\n")

# Extract random samples
bbox <- sits_bbox(planet_cube[1, ])
set.seed(42)

random_points <- data.frame(
    id = 1:SAMPLE_SIZE,
    longitude = runif(SAMPLE_SIZE, bbox["xmin"], bbox["xmax"]),
    latitude = runif(SAMPLE_SIZE, bbox["ymin"], bbox["ymax"])
)

random_points_sf <- sf::st_as_sf(
    random_points,
    coords = c("longitude", "latitude"),
    crs = sf::st_crs(planet_cube[1, ]$crs)[[1]]
)
random_points_sf$label <- "sample"

# Extract time series
pixel_samples <- sits_get_data(
    cube = planet_cube,
    samples = random_points_sf
)

cat("  Extracted", nrow(pixel_samples), "pixel time series\n\n")

# ==============================================================================
# Step 2: Train SOM
# ==============================================================================

cat("Step 2: Training Self-Organizing Map...\n")
cat("  Grid size:", SOM_GRID_X, "x", SOM_GRID_Y, "=", SOM_GRID_X * SOM_GRID_Y, "neurons\n")

# Train SOM
som_model <- sits_som(
    samples = pixel_samples,
    grid_xdim = SOM_GRID_X,
    grid_ydim = SOM_GRID_Y
)

# Classify samples to SOM neurons
pixel_samples_som <- sits_classify(
    data = pixel_samples,
    ml_model = som_model
)

cat("  SOM training complete!\n\n")

# ==============================================================================
# Step 3: Analyze SOM neurons
# ==============================================================================

cat("Step 3: Analyzing SOM neuron patterns...\n\n")

# Count samples per neuron
neuron_counts <- table(pixel_samples_som$predicted)

cat("Neuron distribution:\n")
cat("  Total neurons:", SOM_GRID_X * SOM_GRID_Y, "\n")
cat("  Neurons with samples:", length(neuron_counts), "\n")
cat("  Samples per neuron (mean):", round(mean(neuron_counts)), "\n")
cat("  Samples per neuron (median):", median(neuron_counts), "\n\n")

# For each neuron, calculate mean spectral characteristics
cat("Top neurons by size:\n")
top_neurons <- sort(neuron_counts, decreasing = TRUE)[1:min(10, length(neuron_counts))]

for (i in seq_along(top_neurons)) {
    neuron_label <- names(top_neurons)[i]
    count <- top_neurons[i]
    cat("  Neuron", neuron_label, ":", count, "pixels\n")
}
cat("\n")

# ==============================================================================
# Step 4: Extract representative points from each neuron
# ==============================================================================

cat("Step 4: Extracting representative sample points...\n")

if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Get unique neuron labels
unique_neurons <- unique(pixel_samples_som$predicted)

all_sample_points <- list()

for (neuron_label in unique_neurons) {
    neuron_samples <- pixel_samples_som[pixel_samples_som$predicted == neuron_label, ]

    # Extract up to POINTS_PER_NEURON samples
    n_points <- min(POINTS_PER_NEURON, nrow(neuron_samples))

    if (n_points > 0) {
        # Randomly select samples
        sample_indices <- sample(1:nrow(neuron_samples), n_points)
        selected_samples <- neuron_samples[sample_indices, ]

        # Get coordinates
        coords <- sf::st_coordinates(selected_samples)

        # Create data frame
        points_df <- data.frame(
            neuron = neuron_label,
            longitude = coords[, "X"],
            latitude = coords[, "Y"],
            label = "",  # Empty for user to fill
            start_date = "",
            end_date = ""
        )

        all_sample_points[[neuron_label]] <- points_df
    }
}

# Combine all points
sample_points_df <- do.call(rbind, all_sample_points)

cat("  Extracted", nrow(sample_points_df), "sample points from", length(unique_neurons), "neurons\n\n")

# ==============================================================================
# Step 5: Save results
# ==============================================================================

cat("Step 5: Saving results...\n")

# Save as CSV
csv_file <- file.path(OUTPUT_DIR, "som_sample_points.csv")
write.csv(sample_points_df, csv_file, row.names = FALSE)
cat("  CSV saved:", csv_file, "\n")

# Save as GeoPackage
sample_points_sf <- sf::st_as_sf(
    sample_points_df,
    coords = c("longitude", "latitude"),
    crs = sf::st_crs(planet_cube[1, ]$crs)[[1]]
)

gpkg_file <- file.path(OUTPUT_DIR, "som_sample_points.gpkg")
sf::st_write(sample_points_sf, gpkg_file, delete_dsn = TRUE, quiet = TRUE)
cat("  GeoPackage saved:", gpkg_file, "\n\n")

# ==============================================================================
# Step 6: Summary
# ==============================================================================

cat("========================================\n")
cat("SOM Analysis Complete!\n")
cat("========================================\n\n")

cat("Results:\n")
cat("  - Trained SOM with", SOM_GRID_X * SOM_GRID_Y, "neurons\n")
cat("  - Identified", length(unique_neurons), "distinct patterns\n")
cat("  - Extracted", nrow(sample_points_df), "sample points\n\n")

cat("Next steps:\n\n")

cat("1. Open sample points in QGIS:\n")
cat("   ", gpkg_file, "\n\n")

cat("2. Review temporal patterns:\n")
cat("   - Points with same 'neuron' value have similar temporal patterns\n")
cat("   - Use PlanetScope imagery to identify land cover\n")
cat("   - Fill in 'label', 'start_date', 'end_date' fields\n\n")

cat("3. Create training samples:\n")
cat("   - Keep points where land cover is clear\n")
cat("   - Delete ambiguous points\n")
cat("   - Add more samples for important classes\n")
cat("   - Export as training_samples.gpkg\n\n")

cat("4. Run supervised classification:\n")
cat("   Rscript scripts/classify_planetscope.R\n\n")

cat("TIP: SOM groups pixels with similar TEMPORAL BEHAVIOR.\n")
cat("     Neurons don't directly correspond to land cover classes,\n")
cat("     but help you find areas with distinct patterns!\n\n")
