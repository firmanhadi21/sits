#!/usr/bin/env Rscript
# End-to-end PlanetScope classification with sits
# This script:
# 1. Creates a sits cube from processed PlanetScope data
# 2. Loads training samples
# 3. Extracts time series from the cube
# 4. Trains a classification model
# 5. Classifies the cube
# 6. Post-processes and saves results

suppressPackageStartupMessages({
    library(sits)
    library(sf)
})

cat("========================================\n")
cat("PlanetScope Classification Pipeline\n")
cat("========================================\n\n")

# ==============================================================================
# Configuration
# ==============================================================================

# Paths
DATA_DIR <- "data/planetscope_processed"
SAMPLES_FILE <- "data/training_samples.gpkg"  # or .shp, .geojson
OUTPUT_DIR <- "data/classification_results"
MODEL_FILE <- file.path(OUTPUT_DIR, "model.rds")

# Classification parameters
BANDS <- c("B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8")
CLASSIFIER <- "rf"  # Options: "rf", "xgboost", "svm", "lightgbm"

# Post-processing
APPLY_SMOOTHING <- TRUE
SMOOTHING_WINDOW <- 3  # Number of temporal observations for smoothing

# Memory management
MEMSIZE <- 8  # GB
MULTICORES <- 4

# ==============================================================================
# Step 1: Create sits cube
# ==============================================================================

cat("Step 1: Creating sits cube...\n")

planet_cube <- sits_cube(
    source = "PLANET",
    collection = "MOSAIC-8B",
    data_dir = DATA_DIR,
    parse_info = c("date", "X1", "X2", "tile", "X3", "X4", "X5", "X6", "X7", "X8", "band"),
    delim = "_"
)

cat("  Cube created successfully!\n")
cat("  Tiles:", nrow(planet_cube), "\n")
cat("  Timeline:", length(sits_timeline(planet_cube)), "dates\n")
cat("  Date range:", min(sits_timeline(planet_cube)), "to", max(sits_timeline(planet_cube)), "\n")
cat("  Bands:", paste(sits_bands(planet_cube), collapse = ", "), "\n\n")

# ==============================================================================
# Step 2: Load training samples
# ==============================================================================

cat("Step 2: Loading training samples...\n")

if (!file.exists(SAMPLES_FILE)) {
    cat("\n")
    cat("  WARNING: Training samples file not found!\n")
    cat("  Expected file:", SAMPLES_FILE, "\n\n")
    cat("  Please create training samples with the following requirements:\n")
    cat("  - Spatial format: GeoPackage (.gpkg), Shapefile (.shp), or GeoJSON (.geojson)\n")
    cat("  - Must contain a 'label' column with class names\n")
    cat("  - RECOMMENDED: Include 'start_date' and 'end_date' columns (YYYY-MM-DD format)\n")
    cat("    This ensures labels only apply to the correct time period\n")
    cat("  - Coordinate system must match the PlanetScope data (typically UTM)\n\n")
    cat("  Example CSV format:\n")
    cat("    longitude,latitude,label,start_date,end_date\n")
    cat("    -47.123,10.456,forest,2023-01-01,2025-12-31\n")
    cat("    -47.124,10.457,water,2024-01-01,2024-12-31\n\n")
    cat("  Convert CSV to GeoPackage:\n")
    cat("    source('scripts/prepare_training_samples.R')\n")
    cat("    samples <- create_samples_from_csv(\n")
    cat("        csv_file = 'data/training_points.csv',\n")
    cat("        output_file = '", SAMPLES_FILE, "'\n", sep = "")
    cat("    )\n\n")
    stop("Cannot proceed without training samples")
}

# Read training samples
training_samples_sf <- sf::st_read(SAMPLES_FILE, quiet = TRUE)

cat("  Loaded", nrow(training_samples_sf), "samples\n")
cat("  Classes:", paste(unique(training_samples_sf$label), collapse = ", "), "\n")

# Check for date information
has_dates <- "start_date" %in% names(training_samples_sf) &&
             "end_date" %in% names(training_samples_sf)

if (has_dates) {
    cat("  Date information: YES\n")
    training_samples_sf$start_date <- as.Date(training_samples_sf$start_date)
    training_samples_sf$end_date <- as.Date(training_samples_sf$end_date)
    cat("  Sample date range:", min(training_samples_sf$start_date, na.rm = TRUE),
        "to", max(training_samples_sf$end_date, na.rm = TRUE), "\n")
} else {
    cat("  Date information: NO - will use entire time series\n")
    cat("  RECOMMENDATION: Add start_date and end_date columns to samples\n")
    cat("  This ensures labels are only applied to correct time periods.\n")
}
cat("\n")

# ==============================================================================
# Step 3: Extract time series for training samples
# ==============================================================================

cat("Step 3: Extracting time series from cube...\n")

training_data <- sits_get_data(
    cube = planet_cube,
    samples = training_samples_sf
)

# If samples have date information, filter time series to valid date range
if (has_dates) {
    cat("  Filtering time series to valid date ranges...\n")

    for (i in seq_len(nrow(training_data))) {
        ts <- training_data$time_series[[i]]
        start_date <- training_data$start_date[i]
        end_date <- training_data$end_date[i]

        # Filter to date range
        ts_filtered <- ts[ts$Index >= start_date & ts$Index <= end_date, ]

        # Update time series
        training_data$time_series[[i]] <- ts_filtered
    }

    cat("  Time series filtered to sample-specific date ranges\n")
}

cat("  Extracted time series for", nrow(training_data), "samples\n")
cat("  Time series length:", nrow(training_data$time_series[[1]]), "dates\n\n")

# Check if we have enough samples per class
sample_counts <- table(training_data$label)
cat("  Samples per class:\n")
for (class_name in names(sample_counts)) {
    cat("    -", class_name, ":", sample_counts[class_name], "\n")
}
cat("\n")

# Warning if any class has too few samples
min_samples <- 30
low_sample_classes <- names(sample_counts[sample_counts < min_samples])
if (length(low_sample_classes) > 0) {
    cat("  WARNING: Some classes have fewer than", min_samples, "samples:\n")
    cat("  ", paste(low_sample_classes, collapse = ", "), "\n")
    cat("  Consider collecting more samples for better model performance.\n\n")
}

# ==============================================================================
# Step 4: Train classification model
# ==============================================================================

cat("Step 4: Training", toupper(CLASSIFIER), "model...\n")

# Create output directory if it doesn't exist
if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Train model based on selected classifier
model <- switch(CLASSIFIER,
    "rf" = sits_train(
        samples = training_data,
        ml_method = sits_rfor(num_trees = 500)
    ),
    "xgboost" = sits_train(
        samples = training_data,
        ml_method = sits_xgboost(nrounds = 100)
    ),
    "svm" = sits_train(
        samples = training_data,
        ml_method = sits_svm()
    ),
    "lightgbm" = sits_train(
        samples = training_data,
        ml_method = sits_lightgbm(num_iterations = 100)
    ),
    stop("Unknown classifier: ", CLASSIFIER)
)

cat("  Model trained successfully!\n\n")

# Evaluate model with cross-validation
cat("  Evaluating model accuracy...\n")
model_accuracy <- sits_kfold_validate(
    samples = training_data,
    folds = 5,
    ml_method = switch(CLASSIFIER,
        "rf" = sits_rfor(num_trees = 500),
        "xgboost" = sits_xgboost(nrounds = 100),
        "svm" = sits_svm(),
        "lightgbm" = sits_lightgbm(num_iterations = 100)
    )
)

cat("\n  Cross-validation results:\n")
print(model_accuracy)
cat("\n")

# Save model
saveRDS(model, MODEL_FILE)
cat("  Model saved to:", MODEL_FILE, "\n\n")

# ==============================================================================
# Step 5: Classify the cube
# ==============================================================================

cat("Step 5: Classifying cube...\n")

classified_cube <- sits_classify(
    data = planet_cube,
    ml_model = model,
    output_dir = OUTPUT_DIR,
    memsize = MEMSIZE,
    multicores = MULTICORES,
    version = "v1"
)

cat("  Classification complete!\n\n")

# ==============================================================================
# Step 6: Post-processing (optional smoothing)
# ==============================================================================

if (APPLY_SMOOTHING) {
    cat("Step 6: Applying Bayesian smoothing...\n")

    smoothed_cube <- sits_smooth(
        cube = classified_cube,
        output_dir = OUTPUT_DIR,
        window_size = SMOOTHING_WINDOW,
        memsize = MEMSIZE,
        multicores = MULTICORES,
        version = "v1_smoothed"
    )

    cat("  Smoothing complete!\n\n")
} else {
    cat("Step 6: Skipping smoothing (APPLY_SMOOTHING = FALSE)\n\n")
    smoothed_cube <- classified_cube
}

# ==============================================================================
# Step 7: Generate outputs
# ==============================================================================

cat("Step 7: Generating outputs...\n")

# Create label cube (converts probabilities to final classification)
label_cube <- sits_label_classification(
    cube = smoothed_cube,
    output_dir = OUTPUT_DIR,
    version = "v1_labels"
)

cat("  Label map created!\n")
cat("\n")
cat("========================================\n")
cat("Classification Complete!\n")
cat("========================================\n\n")

cat("Output files in:", OUTPUT_DIR, "\n\n")

cat("To visualize results in R:\n")
cat("  # Load the cube\n")
cat("  result_cube <- sits_cube(source = 'BDC',\n")
cat("                           collection = 'MOSAIC-8B-CLASS',\n")
cat("                           data_dir = '", OUTPUT_DIR, "')\n\n", sep = "")
cat("  # Plot classification map\n")
cat("  plot(result_cube)\n\n")

cat("To load in QGIS:\n")
cat("  1. Open QGIS\n")
cat("  2. Add Raster Layer\n")
cat("  3. Navigate to:", OUTPUT_DIR, "\n")
cat("  4. Load the *_class.tif file(s)\n\n")

cat("Model performance summary saved in working directory\n")
cat("Model file:", MODEL_FILE, "\n")
