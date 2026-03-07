#!/usr/bin/env Rscript
# Three-step hierarchical classification using sits
#
# Step 1: Classify into 7 broad classes:
#         water, paddy, ladang, sparse_vegetation, dense_vegetation,
#         built_up, bareland
#
# Step 2: Sub-classify dense_vegetation into:
#         natural_forest, production_forest, agroforest
#
# Step 3: Sub-classify sparse_vegetation into:
#         shrubs, grassland

suppressPackageStartupMessages({
    library(sits)
    library(sf)
})

cat("========================================\n")
cat("Hierarchical Classification Pipeline\n")
cat("========================================\n\n")

# ==============================================================================
# Configuration
# ==============================================================================

# Input data
COMBINED_DIR <- "data/planetscope_combined_masked"
ALL_BANDS <- c("B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8",
               "NDVI", "NDWI", "NDRE", "EVI", "SAVI", "GNDVI", "BSI", "NDTI")

# Training samples (one file per step, each with a "label" column)
SAMPLES_STEP1 <- "data/samples_step1_landcover.gpkg"
SAMPLES_STEP2 <- "data/samples_step2_dense_vegetation.gpkg"
SAMPLES_STEP3 <- "data/samples_step3_sparse_vegetation.gpkg"

# Output directories
OUTPUT_DIR_STEP1 <- "data/classification_step1"
OUTPUT_DIR_STEP2 <- "data/classification_step2"
OUTPUT_DIR_STEP3 <- "data/classification_step3"
OUTPUT_DIR_FINAL <- "data/classification_final"

# Classifier
CLASSIFIER <- "rf"  # Options: "rf", "xgboost", "lightgbm"
NUM_TREES <- 500

# Resources
MEMSIZE <- 8
MULTICORES <- 4

# ==============================================================================
# Helper: train and classify
# ==============================================================================

train_model <- function(training_data, classifier = CLASSIFIER) {
    ml_method <- switch(classifier,
        "rf"       = sits_rfor(num_trees = NUM_TREES),
        "xgboost"  = sits_xgboost(nrounds = 200),
        "lightgbm" = sits_lightgbm(num_iterations = 200),
        stop("Unknown classifier: ", classifier)
    )
    sits_train(samples = training_data, ml_method = ml_method)
}

classify_cube <- function(cube, model, output_dir, version = "v1") {
    if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
    }
    sits_classify(
        data = cube,
        ml_model = model,
        output_dir = output_dir,
        memsize = MEMSIZE,
        multicores = MULTICORES,
        version = version
    )
}

# ==============================================================================
# Step 0: Create sits cube
# ==============================================================================

cat("Step 0: Creating sits cube...\n")

cube <- sits_cube(
    source = "PLANET",
    collection = "MOSAIC-8B",
    data_dir = COMBINED_DIR,
    parse_info = c("date", "tile", "band"),
    delim = "_",
    bands = ALL_BANDS
)

cat("  Tiles:", nrow(cube), "\n")
cat("  Timeline:", length(sits_timeline(cube)), "dates\n")
cat("  Bands:", paste(sits_bands(cube), collapse = ", "), "\n\n")

# ==============================================================================
# Step 1: Broad land cover classification (7 classes)
# ==============================================================================

cat("========================================\n")
cat("STEP 1: Broad Land Cover Classification\n")
cat("========================================\n\n")

# Expected labels: water, paddy, ladang, sparse_vegetation,
#                  dense_vegetation, built_up, bareland

if (!file.exists(SAMPLES_STEP1)) {
    cat("WARNING: Training samples not found:", SAMPLES_STEP1, "\n")
    cat("\nPlease create a GeoPackage with point samples and a 'label' column.\n")
    cat("Labels must be exactly:\n")
    cat("  water, paddy, ladang, sparse_vegetation,\n")
    cat("  dense_vegetation, built_up, bareland\n\n")
    cat("Example using QGIS:\n")
    cat("  1. Create a new GeoPackage point layer\n")
    cat("  2. Add a text field called 'label'\n")
    cat("  3. Add 'start_date' and 'end_date' fields (Date type)\n")
    cat("  4. Digitize training points over the imagery\n")
    cat("  5. Save as:", SAMPLES_STEP1, "\n\n")
    stop("Cannot proceed without Step 1 training samples")
}

cat("Loading Step 1 samples...\n")
samples_sf1 <- sf::st_read(SAMPLES_STEP1, quiet = TRUE)
cat("  Samples:", nrow(samples_sf1), "\n")
cat("  Classes:", paste(sort(unique(samples_sf1$label)), collapse = ", "), "\n\n")

# Validate labels
expected_labels1 <- c("water", "paddy", "ladang", "sparse_vegetation",
                       "dense_vegetation", "built_up", "bareland")
actual_labels1 <- unique(samples_sf1$label)
missing <- setdiff(expected_labels1, actual_labels1)
if (length(missing) > 0) {
    cat("  WARNING: Missing classes:", paste(missing, collapse = ", "), "\n")
    cat("  Classification will proceed but these classes won't be mapped.\n\n")
}

cat("Extracting time series...\n")
training_data1 <- sits_get_data(cube = cube, samples = samples_sf1)

cat("  Samples per class:\n")
for (cl in sort(unique(training_data1$label))) {
    cat("    ", cl, ":", sum(training_data1$label == cl), "\n")
}
cat("\n")

cat("Training Step 1 model...\n")
model1 <- train_model(training_data1)

cat("Cross-validation...\n")
acc1 <- sits_kfold_validate(
    samples = training_data1,
    folds = 5,
    ml_method = sits_rfor(num_trees = NUM_TREES)
)
cat("\n  Step 1 accuracy:\n")
print(sits_accuracy_summary(acc1))
cat("\n")

cat("Classifying cube (Step 1)...\n")
probs_cube1 <- classify_cube(cube, model1, OUTPUT_DIR_STEP1, version = "step1")

cat("Smoothing...\n")
smooth_cube1 <- sits_smooth(
    cube = probs_cube1,
    output_dir = OUTPUT_DIR_STEP1,
    memsize = MEMSIZE,
    multicores = MULTICORES,
    version = "step1_smooth"
)

cat("Labeling...\n")
label_cube1 <- sits_label_classification(
    cube = smooth_cube1,
    output_dir = OUTPUT_DIR_STEP1,
    version = "step1_labels"
)

cat("Step 1 DONE.\n\n")

# Save model
saveRDS(model1, file.path(OUTPUT_DIR_STEP1, "model_step1.rds"))

# ==============================================================================
# Step 2: Sub-classify dense_vegetation
#         -> natural_forest, production_forest, agroforest
# ==============================================================================

cat("========================================\n")
cat("STEP 2: Dense Vegetation Sub-classification\n")
cat("========================================\n\n")

if (!file.exists(SAMPLES_STEP2)) {
    cat("WARNING: Training samples not found:", SAMPLES_STEP2, "\n")
    cat("\nPlease create a GeoPackage with point samples and a 'label' column.\n")
    cat("Labels must be exactly:\n")
    cat("  natural_forest, production_forest, agroforest\n")
    cat("All sample points must fall within dense_vegetation areas.\n\n")
    stop("Cannot proceed without Step 2 training samples")
}

cat("Loading Step 2 samples...\n")
samples_sf2 <- sf::st_read(SAMPLES_STEP2, quiet = TRUE)
cat("  Samples:", nrow(samples_sf2), "\n")
cat("  Classes:", paste(sort(unique(samples_sf2$label)), collapse = ", "), "\n\n")

cat("Extracting time series...\n")
training_data2 <- sits_get_data(cube = cube, samples = samples_sf2)

cat("  Samples per class:\n")
for (cl in sort(unique(training_data2$label))) {
    cat("    ", cl, ":", sum(training_data2$label == cl), "\n")
}
cat("\n")

cat("Training Step 2 model...\n")
model2 <- train_model(training_data2)

cat("Cross-validation...\n")
acc2 <- sits_kfold_validate(
    samples = training_data2,
    folds = 5,
    ml_method = sits_rfor(num_trees = NUM_TREES)
)
cat("\n  Step 2 accuracy:\n")
print(sits_accuracy_summary(acc2))
cat("\n")

cat("Classifying cube (Step 2)...\n")
probs_cube2 <- classify_cube(cube, model2, OUTPUT_DIR_STEP2, version = "step2")

cat("Smoothing...\n")
smooth_cube2 <- sits_smooth(
    cube = probs_cube2,
    output_dir = OUTPUT_DIR_STEP2,
    memsize = MEMSIZE,
    multicores = MULTICORES,
    version = "step2_smooth"
)

cat("Labeling...\n")
label_cube2 <- sits_label_classification(
    cube = smooth_cube2,
    output_dir = OUTPUT_DIR_STEP2,
    version = "step2_labels"
)

cat("Step 2 DONE.\n\n")

saveRDS(model2, file.path(OUTPUT_DIR_STEP2, "model_step2.rds"))

# ==============================================================================
# Step 3: Sub-classify sparse_vegetation
#         -> shrubs, grassland
# ==============================================================================

cat("========================================\n")
cat("STEP 3: Sparse Vegetation Sub-classification\n")
cat("========================================\n\n")

if (!file.exists(SAMPLES_STEP3)) {
    cat("WARNING: Training samples not found:", SAMPLES_STEP3, "\n")
    cat("\nPlease create a GeoPackage with point samples and a 'label' column.\n")
    cat("Labels must be exactly:\n")
    cat("  shrubs, grassland\n")
    cat("All sample points must fall within sparse_vegetation areas.\n\n")
    stop("Cannot proceed without Step 3 training samples")
}

cat("Loading Step 3 samples...\n")
samples_sf3 <- sf::st_read(SAMPLES_STEP3, quiet = TRUE)
cat("  Samples:", nrow(samples_sf3), "\n")
cat("  Classes:", paste(sort(unique(samples_sf3$label)), collapse = ", "), "\n\n")

cat("Extracting time series...\n")
training_data3 <- sits_get_data(cube = cube, samples = samples_sf3)

cat("  Samples per class:\n")
for (cl in sort(unique(training_data3$label))) {
    cat("    ", cl, ":", sum(training_data3$label == cl), "\n")
}
cat("\n")

cat("Training Step 3 model...\n")
model3 <- train_model(training_data3)

cat("Cross-validation...\n")
acc3 <- sits_kfold_validate(
    samples = training_data3,
    folds = 5,
    ml_method = sits_rfor(num_trees = NUM_TREES)
)
cat("\n  Step 3 accuracy:\n")
print(sits_accuracy_summary(acc3))
cat("\n")

cat("Classifying cube (Step 3)...\n")
probs_cube3 <- classify_cube(cube, model3, OUTPUT_DIR_STEP3, version = "step3")

cat("Smoothing...\n")
smooth_cube3 <- sits_smooth(
    cube = probs_cube3,
    output_dir = OUTPUT_DIR_STEP3,
    memsize = MEMSIZE,
    multicores = MULTICORES,
    version = "step3_smooth"
)

cat("Labeling...\n")
label_cube3 <- sits_label_classification(
    cube = smooth_cube3,
    output_dir = OUTPUT_DIR_STEP3,
    version = "step3_labels"
)

cat("Step 3 DONE.\n\n")

saveRDS(model3, file.path(OUTPUT_DIR_STEP3, "model_step3.rds"))

# ==============================================================================
# Step 4: Merge results using sits_reclassify
# ==============================================================================

cat("========================================\n")
cat("STEP 4: Merging Hierarchical Results\n")
cat("========================================\n\n")

if (!dir.exists(OUTPUT_DIR_FINAL)) {
    dir.create(OUTPUT_DIR_FINAL, recursive = TRUE)
}

# 4a: Replace dense_vegetation with Step 2 sub-classes
cat("Merging Step 2 (dense vegetation sub-classes) into Step 1...\n")

merged_step2 <- sits_reclassify(
    cube = label_cube1,
    mask = label_cube2,
    rules = list(
        "natural_forest"    = cube == "dense_vegetation" & mask == "natural_forest",
        "production_forest" = cube == "dense_vegetation" & mask == "production_forest",
        "agroforest"        = cube == "dense_vegetation" & mask == "agroforest"
    ),
    memsize = MEMSIZE,
    multicores = MULTICORES,
    output_dir = OUTPUT_DIR_FINAL,
    version = "merged_step2"
)

cat("  Dense vegetation split into sub-classes.\n\n")

# 4b: Replace sparse_vegetation with Step 3 sub-classes
cat("Merging Step 3 (sparse vegetation sub-classes) into merged map...\n")

final_map <- sits_reclassify(
    cube = merged_step2,
    mask = label_cube3,
    rules = list(
        "shrubs"    = cube == "sparse_vegetation" & mask == "shrubs",
        "grassland" = cube == "sparse_vegetation" & mask == "grassland"
    ),
    memsize = MEMSIZE,
    multicores = MULTICORES,
    output_dir = OUTPUT_DIR_FINAL,
    version = "final"
)

cat("  Sparse vegetation split into sub-classes.\n\n")

# ==============================================================================
# Summary
# ==============================================================================

cat("========================================\n")
cat("Hierarchical Classification Complete!\n")
cat("========================================\n\n")

cat("Final map classes (9 classes):\n")
cat("  From Step 1 (kept as-is):\n")
cat("    - water\n")
cat("    - paddy\n")
cat("    - ladang\n")
cat("    - built_up\n")
cat("    - bareland\n")
cat("  From Step 2 (replaces dense_vegetation):\n")
cat("    - natural_forest\n")
cat("    - production_forest\n")
cat("    - agroforest\n")
cat("  From Step 3 (replaces sparse_vegetation):\n")
cat("    - shrubs\n")
cat("    - grassland\n\n")

cat("Output directories:\n")
cat("  Step 1 (broad):           ", OUTPUT_DIR_STEP1, "\n")
cat("  Step 2 (dense veg):       ", OUTPUT_DIR_STEP2, "\n")
cat("  Step 3 (sparse veg):      ", OUTPUT_DIR_STEP3, "\n")
cat("  Final merged map:         ", OUTPUT_DIR_FINAL, "\n\n")

cat("To visualize in R:\n")
cat("  plot(final_map)\n\n")

cat("To load in QGIS:\n")
cat("  Open the *_class.tif files in:", OUTPUT_DIR_FINAL, "\n\n")

cat("Models saved:\n")
cat("  ", file.path(OUTPUT_DIR_STEP1, "model_step1.rds"), "\n")
cat("  ", file.path(OUTPUT_DIR_STEP2, "model_step2.rds"), "\n")
cat("  ", file.path(OUTPUT_DIR_STEP3, "model_step3.rds"), "\n")
