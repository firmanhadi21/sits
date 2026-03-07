#!/usr/bin/env Rscript
# =============================================================================
# Three-step hierarchical classification using Landsat archives (2015-2025)
# Designed for Posit Cloud (limited RAM and cores)
#
# Data source: Microsoft Planetary Computer (MPC) - free, no token needed
#
# Step 1: 7 broad classes -> water, paddy, ladang, sparse_vegetation,
#                            dense_vegetation, built_up, bareland
# Step 2: dense_vegetation -> natural_forest, production_forest, agroforest
# Step 3: sparse_vegetation -> shrubs, grassland
# =============================================================================

# -- Install sits if needed (run once on Posit Cloud) -------------------------
# install.packages("sits", dependencies = TRUE)

suppressPackageStartupMessages({
    library(sits)
    library(sf)
})

cat("========================================\n")
cat("Hierarchical Classification - Landsat\n")
cat("Posit Cloud Edition\n")
cat("========================================\n\n")

# ==============================================================================
# 1. CONFIGURATION
# ==============================================================================

# Study area ROI (Cisokan, West Java)
# Adjust these coordinates to your study area
ROI <- c(
    lon_min = 106.45, lon_max = 106.65,
    lat_min = -7.20,  lat_max = -7.05
)

# Time period
START_DATE <- "2015-01-01"
END_DATE   <- "2025-12-31"

# Regularization: composites every 16 days at 30m
REG_PERIOD <- "P16D"
REG_RES    <- 30

# Landsat bands to use
BANDS <- c("BLUE", "GREEN", "RED", "NIR08", "SWIR16", "SWIR22")

# Training samples
SAMPLES_STEP1 <- "data/samples_landsat_step1_landcover.gpkg"
SAMPLES_STEP2 <- "data/samples_landsat_step2_dense_vegetation.gpkg"
SAMPLES_STEP3 <- "data/samples_landsat_step3_sparse_vegetation.gpkg"

# Output
OUTPUT_DIR <- "data/landsat_classification"

# Posit Cloud resource limits (conservative)
MEMSIZE    <- 8   # GB - Posit Cloud free tier has ~4GB RAM
MULTICORES <- 4   # Posit Cloud free tier has 1 core (paid: up to 4)

# Classifier
CLASSIFIER <- "rf"
NUM_TREES  <- 300  # fewer trees to save memory

# Processing flags - set FALSE to skip steps you've already completed
RUN_CUBE_CREATION   <- TRUE
RUN_REGULARIZATION  <- TRUE
RUN_STEP1           <- TRUE
RUN_STEP2           <- TRUE
RUN_STEP3           <- TRUE
RUN_MERGE           <- TRUE

# ==============================================================================
# 2. CREATE LANDSAT CUBE FROM MPC (Microsoft Planetary Computer)
# ==============================================================================

if (RUN_CUBE_CREATION) {

cat("Step 1: Searching Landsat archive on MPC...\n")
cat("  ROI: lon [", ROI["lon_min"], ",", ROI["lon_max"], "]",
    " lat [", ROI["lat_min"], ",", ROI["lat_max"], "]\n")
cat("  Period:", START_DATE, "to", END_DATE, "\n\n")

landsat_cube <- sits_cube(
    source     = "MPC",
    collection = "LANDSAT-C2-L2",
    bands      = BANDS,
    roi        = ROI,
    start_date = START_DATE,
    end_date   = END_DATE,
    progress   = TRUE
)

cat("\n  Tiles found:", nrow(landsat_cube), "\n")
cat("  Timeline:", length(sits_timeline(landsat_cube)), "dates\n")
cat("  Bands:", paste(sits_bands(landsat_cube), collapse = ", "), "\n\n")

saveRDS(landsat_cube, file.path(OUTPUT_DIR, "landsat_cube_raw.rds"))

} else {
    cat("Skipping cube creation (loading saved cube)...\n")
    landsat_cube <- readRDS(file.path(OUTPUT_DIR, "landsat_cube_raw.rds"))
}

# ==============================================================================
# 3. REGULARIZE (create cloud-free composites)
# ==============================================================================

if (RUN_REGULARIZATION) {

cat("Step 2: Regularizing cube (cloud-free composites)...\n")
cat("  Period:", REG_PERIOD, "\n")
cat("  Resolution:", REG_RES, "m\n")
cat("  This may take a while on Posit Cloud...\n\n")

REG_DIR <- file.path(OUTPUT_DIR, "regularized")
if (!dir.exists(REG_DIR)) dir.create(REG_DIR, recursive = TRUE)

reg_cube <- sits_regularize(
    cube       = landsat_cube,
    period     = REG_PERIOD,
    res        = REG_RES,
    roi        = ROI,
    output_dir = REG_DIR,
    multicores = MULTICORES,
    progress   = TRUE
)

cat("\n  Regularized cube created!\n")
cat("  Timeline:", length(sits_timeline(reg_cube)), "dates\n\n")

saveRDS(reg_cube, file.path(OUTPUT_DIR, "landsat_cube_regularized.rds"))

} else {
    cat("Skipping regularization (loading saved cube)...\n")
    reg_cube <- readRDS(file.path(OUTPUT_DIR, "landsat_cube_regularized.rds"))
}

# ==============================================================================
# 4. ADD SPECTRAL INDICES
# ==============================================================================

cat("Step 3: Adding spectral indices...\n")

reg_cube <- sits_apply(
    data       = reg_cube,
    NDVI       = (NIR08 - RED) / (NIR08 + RED),
    output_dir = file.path(OUTPUT_DIR, "regularized"),
    memsize    = MEMSIZE,
    multicores = MULTICORES,
    progress   = TRUE
)

reg_cube <- sits_apply(
    data       = reg_cube,
    NDWI       = (GREEN - NIR08) / (GREEN + NIR08),
    output_dir = file.path(OUTPUT_DIR, "regularized"),
    memsize    = MEMSIZE,
    multicores = MULTICORES,
    progress   = TRUE
)

reg_cube <- sits_apply(
    data       = reg_cube,
    NDBI       = (SWIR16 - NIR08) / (SWIR16 + NIR08),
    output_dir = file.path(OUTPUT_DIR, "regularized"),
    memsize    = MEMSIZE,
    multicores = MULTICORES,
    progress   = TRUE
)

reg_cube <- sits_apply(
    data       = reg_cube,
    EVI        = 2.5 * (NIR08 - RED) / (NIR08 + 6 * RED - 7.5 * BLUE + 1),
    output_dir = file.path(OUTPUT_DIR, "regularized"),
    memsize    = MEMSIZE,
    multicores = MULTICORES,
    progress   = TRUE
)

cat("  Bands now:", paste(sits_bands(reg_cube), collapse = ", "), "\n\n")

saveRDS(reg_cube, file.path(OUTPUT_DIR, "landsat_cube_with_indices.rds"))

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

train_model <- function(training_data) {
    ml_method <- switch(CLASSIFIER,
        "rf"       = sits_rfor(num_trees = NUM_TREES),
        "xgboost"  = sits_xgboost(nrounds = 150),
        "lightgbm" = sits_lightgbm(num_iterations = 150)
    )
    sits_train(samples = training_data, ml_method = ml_method)
}

classify_and_label <- function(cube, model, out_dir, step_name) {
    if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

    cat("  Classifying...\n")
    probs <- sits_classify(
        data       = cube,
        ml_model   = model,
        output_dir = out_dir,
        memsize    = MEMSIZE,
        multicores = MULTICORES,
        version    = step_name
    )

    cat("  Smoothing...\n")
    smooth <- sits_smooth(
        cube       = probs,
        output_dir = out_dir,
        memsize    = MEMSIZE,
        multicores = MULTICORES,
        version    = paste0(step_name, "_smooth")
    )

    cat("  Labeling...\n")
    labels <- sits_label_classification(
        cube       = smooth,
        output_dir = out_dir,
        version    = paste0(step_name, "_labels")
    )

    labels
}

# ==============================================================================
# 5. STEP 1 - BROAD LAND COVER (7 classes)
# ==============================================================================

if (RUN_STEP1) {

cat("========================================\n")
cat("STEP 1: Broad Land Cover (7 classes)\n")
cat("========================================\n\n")

if (!file.exists(SAMPLES_STEP1)) {
    stop("Training samples not found: ", SAMPLES_STEP1,
         "\nRun scripts/create_classification_samples.R first, ",
         "then edit the .gpkg in QGIS with real sample locations.")
}

samples_sf1 <- sf::st_read(SAMPLES_STEP1, quiet = TRUE)
cat("  Samples loaded:", nrow(samples_sf1), "\n")
cat("  Classes:", paste(sort(unique(samples_sf1$label)), collapse = ", "), "\n\n")

cat("  Extracting time series...\n")
training1 <- sits_get_data(cube = reg_cube, samples = samples_sf1)
cat("  Extracted", nrow(training1), "samples\n\n")

cat("  Training model...\n")
model1 <- train_model(training1)
saveRDS(model1, file.path(OUTPUT_DIR, "model_step1.rds"))

cat("  Cross-validation...\n")
acc1 <- sits_kfold_validate(
    samples   = training1,
    folds     = 5,
    ml_method = sits_rfor(num_trees = NUM_TREES)
)
print(sits_accuracy_summary(acc1))
cat("\n")

label_cube1 <- classify_and_label(
    reg_cube, model1,
    file.path(OUTPUT_DIR, "step1"), "step1"
)

cat("Step 1 DONE.\n\n")
saveRDS(label_cube1, file.path(OUTPUT_DIR, "label_cube_step1.rds"))

} else {
    cat("Skipping Step 1 (loading saved result)...\n")
    label_cube1 <- readRDS(file.path(OUTPUT_DIR, "label_cube_step1.rds"))
    model1 <- readRDS(file.path(OUTPUT_DIR, "model_step1.rds"))
}

# ==============================================================================
# 6. STEP 2 - DENSE VEGETATION SUB-CLASSES (3 classes)
# ==============================================================================

if (RUN_STEP2) {

cat("========================================\n")
cat("STEP 2: Dense Vegetation (3 classes)\n")
cat("========================================\n\n")

if (!file.exists(SAMPLES_STEP2)) {
    stop("Training samples not found: ", SAMPLES_STEP2)
}

samples_sf2 <- sf::st_read(SAMPLES_STEP2, quiet = TRUE)
cat("  Samples loaded:", nrow(samples_sf2), "\n")
cat("  Classes:", paste(sort(unique(samples_sf2$label)), collapse = ", "), "\n\n")

cat("  Extracting time series...\n")
training2 <- sits_get_data(cube = reg_cube, samples = samples_sf2)
cat("  Extracted", nrow(training2), "samples\n\n")

cat("  Training model...\n")
model2 <- train_model(training2)
saveRDS(model2, file.path(OUTPUT_DIR, "model_step2.rds"))

cat("  Cross-validation...\n")
acc2 <- sits_kfold_validate(
    samples   = training2,
    folds     = 5,
    ml_method = sits_rfor(num_trees = NUM_TREES)
)
print(sits_accuracy_summary(acc2))
cat("\n")

label_cube2 <- classify_and_label(
    reg_cube, model2,
    file.path(OUTPUT_DIR, "step2"), "step2"
)

cat("Step 2 DONE.\n\n")
saveRDS(label_cube2, file.path(OUTPUT_DIR, "label_cube_step2.rds"))

} else {
    cat("Skipping Step 2 (loading saved result)...\n")
    label_cube2 <- readRDS(file.path(OUTPUT_DIR, "label_cube_step2.rds"))
}

# ==============================================================================
# 7. STEP 3 - SPARSE VEGETATION SUB-CLASSES (2 classes)
# ==============================================================================

if (RUN_STEP3) {

cat("========================================\n")
cat("STEP 3: Sparse Vegetation (2 classes)\n")
cat("========================================\n\n")

if (!file.exists(SAMPLES_STEP3)) {
    stop("Training samples not found: ", SAMPLES_STEP3)
}

samples_sf3 <- sf::st_read(SAMPLES_STEP3, quiet = TRUE)
cat("  Samples loaded:", nrow(samples_sf3), "\n")
cat("  Classes:", paste(sort(unique(samples_sf3$label)), collapse = ", "), "\n\n")

cat("  Extracting time series...\n")
training3 <- sits_get_data(cube = reg_cube, samples = samples_sf3)
cat("  Extracted", nrow(training3), "samples\n\n")

cat("  Training model...\n")
model3 <- train_model(training3)
saveRDS(model3, file.path(OUTPUT_DIR, "model_step3.rds"))

cat("  Cross-validation...\n")
acc3 <- sits_kfold_validate(
    samples   = training3,
    folds     = 5,
    ml_method = sits_rfor(num_trees = NUM_TREES)
)
print(sits_accuracy_summary(acc3))
cat("\n")

label_cube3 <- classify_and_label(
    reg_cube, model3,
    file.path(OUTPUT_DIR, "step3"), "step3"
)

cat("Step 3 DONE.\n\n")
saveRDS(label_cube3, file.path(OUTPUT_DIR, "label_cube_step3.rds"))

} else {
    cat("Skipping Step 3 (loading saved result)...\n")
    label_cube3 <- readRDS(file.path(OUTPUT_DIR, "label_cube_step3.rds"))
}

# ==============================================================================
# 8. MERGE - Combine hierarchical results
# ==============================================================================

if (RUN_MERGE) {

cat("========================================\n")
cat("MERGING: Combining Hierarchical Results\n")
cat("========================================\n\n")

FINAL_DIR <- file.path(OUTPUT_DIR, "final")
if (!dir.exists(FINAL_DIR)) dir.create(FINAL_DIR, recursive = TRUE)

# Replace dense_vegetation with Step 2 sub-classes
cat("  Merging dense vegetation sub-classes...\n")
merged_step2 <- sits_reclassify(
    cube = label_cube1,
    mask = label_cube2,
    rules = list(
        "natural_forest"    = cube == "dense_vegetation" & mask == "natural_forest",
        "production_forest" = cube == "dense_vegetation" & mask == "production_forest",
        "agroforest"        = cube == "dense_vegetation" & mask == "agroforest"
    ),
    memsize    = MEMSIZE,
    multicores = MULTICORES,
    output_dir = FINAL_DIR,
    version    = "merged_dense"
)

# Replace sparse_vegetation with Step 3 sub-classes
cat("  Merging sparse vegetation sub-classes...\n")
final_map <- sits_reclassify(
    cube = merged_step2,
    mask = label_cube3,
    rules = list(
        "shrubs"    = cube == "sparse_vegetation" & mask == "shrubs",
        "grassland" = cube == "sparse_vegetation" & mask == "grassland"
    ),
    memsize    = MEMSIZE,
    multicores = MULTICORES,
    output_dir = FINAL_DIR,
    version    = "final"
)

saveRDS(final_map, file.path(OUTPUT_DIR, "final_map.rds"))

cat("\nMerge DONE.\n\n")

} else {
    cat("Skipping merge (loading saved result)...\n")
    final_map <- readRDS(file.path(OUTPUT_DIR, "final_map.rds"))
}

# ==============================================================================
# 9. SUMMARY
# ==============================================================================

cat("========================================\n")
cat("Classification Complete!\n")
cat("========================================\n\n")

cat("Final 9-class map:\n")
cat("  water, paddy, ladang, built_up, bareland,\n")
cat("  natural_forest, production_forest, agroforest,\n")
cat("  shrubs, grassland\n\n")

cat("Outputs in:", OUTPUT_DIR, "\n\n")

cat("Visualize:\n")
cat("  plot(final_map)\n")
cat("  plot(final_map, palette = \"Spectral\")\n\n")

cat("Export to GeoTIFF (for QGIS):\n")
cat("  # Files are already in:", file.path(OUTPUT_DIR, "final"), "\n")
cat("  # Look for *_class.tif files\n")
