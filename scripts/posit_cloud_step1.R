#!/usr/bin/env Rscript
# =============================================================================
# Step 1 Classification - PlanetScope on Posit Cloud
#
# Prerequisites:
#   1. Upload data/planetscope_mosaicked_masked/ (8 bands, ~6.3 GB) to Posit Cloud
#   2. Upload data/samples_planet_step1_landcover.gpkg
#   3. Upload config_source_planet.yml (from inst/extdata/sources/)
#   4. Install sits: install.packages("sits", dependencies = TRUE)
#
# Upload structure on Posit Cloud:
#   /cloud/project/data/planetscope_mosaicked_masked/
#     20230114_B1.tif, 20230114_B2.tif, ..., 20230114_B8.tif
#     20230528_B1.tif, ...
#   /cloud/project/data/samples_planet_step1_landcover.gpkg
# =============================================================================

suppressPackageStartupMessages({
    library(sits)
    library(sf)
})

cat("========================================\n")
cat("PlanetScope Step 1 - Posit Cloud\n")
cat("========================================\n\n")

# ==============================================================================
# Register custom PLANET source (not in standard CRAN sits)
# Upload config_source_planet.yml to your Posit Cloud project root
# ==============================================================================

PLANET_CONFIG <- "config_source_planet.yml"
if (!file.exists(PLANET_CONFIG)) {
    # Also check in inst/extdata/sources/
    PLANET_CONFIG <- "inst/extdata/sources/config_source_planet.yml"
}
if (file.exists(PLANET_CONFIG)) {
    sits_config(config_user_file = PLANET_CONFIG)
    cat("Registered PLANET source from:", PLANET_CONFIG, "\n\n")
} else {
    stop("PLANET config not found!\n",
         "Upload config_source_planet.yml to your Posit Cloud project.\n",
         "Get it from: inst/extdata/sources/config_source_planet.yml")
}

# ==============================================================================
# Configuration
# ==============================================================================

BAND_DIR    <- "data/planetscope_mosaicked_masked"
CUBE_DIR    <- "data/planetscope_cube"       # bands + indices with TILE name
INDEX_DIR   <- "data/planetscope_cube"       # indices go here too
REG_DIR     <- "data/planetscope_regularized"
OUTPUT_DIR  <- "data/classification_step1"
SAMPLES     <- "data/samples_planet_step1_landcover.gpkg"

MEMSIZE    <- 4
MULTICORES <- 1   # Posit Cloud typically 1 core

NUM_TREES  <- 500

# Processing flags - set FALSE to resume from a completed step
DO_SETUP     <- TRUE
DO_INDICES   <- TRUE
DO_REGULARIZE <- TRUE
DO_CLASSIFY  <- TRUE

# ==============================================================================
# Step 1: Organize files (add TILE to filenames for sits)
# ==============================================================================

if (DO_SETUP) {

cat("Step 1: Organizing band files...\n")

dir.create(CUBE_DIR, showWarnings = FALSE, recursive = TRUE)

band_files <- list.files(BAND_DIR, pattern = "\\.tif$", full.names = TRUE)
cat("  Found", length(band_files), "band files\n")

for (f in band_files) {
    fname <- basename(f)
    # 20230114_B1.tif -> 20230114_TILE_B1.tif
    new_name <- sub("^(\\d{8})_(B\\d)\\.tif$", "\\1_TILE_\\2.tif", fname)
    dst <- file.path(CUBE_DIR, new_name)
    if (!file.exists(dst)) {
        file.symlink(normalizePath(f), dst)
    }
}

cat("  Linked to", CUBE_DIR, "\n\n")

# Fix CRS: some files have different WKT axis labels, causing sits to
# see multiple CRS. Standardize all files to the same CRS (from first file).
cat("  Standardizing CRS across all files...\n")
library(terra)
ref_file <- list.files(CUBE_DIR, pattern = "\\.tif$", full.names = TRUE)[1]
ref_crs <- crs(rast(ref_file))

cube_files <- list.files(CUBE_DIR, pattern = "_TILE_B\\d\\.tif$", full.names = TRUE)
for (f in cube_files) {
    r <- rast(f)
    if (crs(r) != ref_crs) {
        tmp_file <- paste0(f, ".tmp.tif")
        crs(r) <- ref_crs
        writeRaster(r, tmp_file, gdal = c("COMPRESS=LZW"))
        file.rename(tmp_file, f)
        cat("    Fixed CRS:", basename(f), "\n")
    }
}
cat("  CRS standardized.\n\n")

}

# ==============================================================================
# Step 2: Compute spectral indices
# ==============================================================================

if (DO_INDICES) {

cat("Step 2: Computing spectral indices...\n")

# Create cube from bands only
cube_bands <- sits_cube(
    source = "PLANET",
    collection = "MOSAIC-8B",
    data_dir = CUBE_DIR,
    parse_info = c("date", "tile", "band"),
    delim = "_",
    bands = c("B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8")
)

# Keep first tile only (in case of duplicate WKT issue)
if (nrow(cube_bands) > 1) {
    cube_bands <- cube_bands[1, ]
}

cat("  Cube: ", nrow(cube_bands), "tile,",
    length(sits_timeline(cube_bands)), "dates\n\n")

# PlanetScope 8-band mapping:
# B1=Coastal Blue, B2=Blue, B3=Green-I, B4=Green, B5=Yellow,
# B6=Red, B7=Red-Edge, B8=NIR

cat("  Computing NDVI = (NIR - Red) / (NIR + Red)...\n")
cube_bands <- sits_apply(
    data = cube_bands,
    NDVI = (B8 - B6) / (B8 + B6),
    output_dir = CUBE_DIR,
    memsize = MEMSIZE, multicores = MULTICORES, progress = TRUE
)

cat("  Computing NDWI = (Green - NIR) / (Green + NIR)...\n")
cube_bands <- sits_apply(
    data = cube_bands,
    NDWI = (B4 - B8) / (B4 + B8),
    output_dir = CUBE_DIR,
    memsize = MEMSIZE, multicores = MULTICORES, progress = TRUE
)

cat("  Computing NDRE = (NIR - RedEdge) / (NIR + RedEdge)...\n")
cube_bands <- sits_apply(
    data = cube_bands,
    NDRE = (B8 - B7) / (B8 + B7),
    output_dir = CUBE_DIR,
    memsize = MEMSIZE, multicores = MULTICORES, progress = TRUE
)

cat("  Computing EVI = 2.5*(NIR - Red) / (NIR + 6*Red - 7.5*Blue + 1)...\n")
cube_bands <- sits_apply(
    data = cube_bands,
    EVI = 2.5 * (B8 - B6) / (B8 + 6 * B6 - 7.5 * B2 + 1),
    output_dir = CUBE_DIR,
    memsize = MEMSIZE, multicores = MULTICORES, progress = TRUE
)

cat("\n  Bands now:", paste(sits_bands(cube_bands), collapse = ", "), "\n\n")

saveRDS(cube_bands, file.path(CUBE_DIR, "cube_with_indices.rds"))
cat("  Saved cube: ", file.path(CUBE_DIR, "cube_with_indices.rds"), "\n\n")

} else {
    cat("Loading saved cube with indices...\n")
    cube_bands <- readRDS(file.path(CUBE_DIR, "cube_with_indices.rds"))
}

# ==============================================================================
# Step 3: Regularize
# ==============================================================================

if (DO_REGULARIZE) {

cat("Step 3: Regularizing cube (P1M composites)...\n")
cat("  This may take a while...\n\n")

dir.create(REG_DIR, showWarnings = FALSE, recursive = TRUE)

reg_cube <- sits_regularize(
    cube       = cube_bands,
    period     = "P1M",
    res        = 3,
    output_dir = REG_DIR,
    multicores = MULTICORES,
    progress   = TRUE
)

cat("\n  Regularized timeline:", length(sits_timeline(reg_cube)), "dates\n")
print(sits_timeline(reg_cube))

saveRDS(reg_cube, file.path(REG_DIR, "reg_cube.rds"))
cat("\n  Saved:", file.path(REG_DIR, "reg_cube.rds"), "\n\n")

} else {
    cat("Loading saved regularized cube...\n")
    reg_cube <- readRDS(file.path(REG_DIR, "reg_cube.rds"))
}

# ==============================================================================
# Step 4: Train and classify
# ==============================================================================

if (DO_CLASSIFY) {

cat("========================================\n")
cat("Step 4: Classification\n")
cat("========================================\n\n")

# Load samples
if (!file.exists(SAMPLES)) {
    stop("Training samples not found: ", SAMPLES)
}

samples_sf <- sf::st_read(SAMPLES, quiet = TRUE)
cat("  Samples:", nrow(samples_sf), "\n")
cat("  Classes:", paste(sort(unique(samples_sf$label)), collapse = ", "), "\n\n")

# Extract time series
cat("  Extracting time series...\n")
training_data <- sits_get_data(cube = reg_cube, samples = samples_sf)
cat("  Extracted", nrow(training_data), "samples\n")
cat("  Time series length:", nrow(training_data$time_series[[1]]), "dates\n\n")

cat("  Samples per class:\n")
for (cl in sort(unique(training_data$label))) {
    cat("    ", cl, ":", sum(training_data$label == cl), "\n")
}
cat("\n")

# Save training data (in case we need to retrain without re-extracting)
saveRDS(training_data, file.path(OUTPUT_DIR, "training_data_step1.rds"))

# Train
cat("  Training Random Forest (", NUM_TREES, "trees)...\n")
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

model <- sits_train(
    samples = training_data,
    ml_method = sits_rfor(num_trees = NUM_TREES)
)
saveRDS(model, file.path(OUTPUT_DIR, "model_step1.rds"))
cat("  Model saved.\n\n")

# Cross-validation
cat("  Cross-validation (5-fold)...\n")
acc <- sits_kfold_validate(
    samples = training_data,
    folds = 5,
    ml_method = sits_rfor(num_trees = NUM_TREES)
)
cat("\n")
print(sits_accuracy_summary(acc))
cat("\n")

# Classify
cat("  Classifying cube...\n")
probs_cube <- sits_classify(
    data       = reg_cube,
    ml_model   = model,
    output_dir = OUTPUT_DIR,
    memsize    = MEMSIZE,
    multicores = MULTICORES,
    version    = "step1"
)
cat("  Done.\n\n")

# Smooth
cat("  Smoothing...\n")
smooth_cube <- sits_smooth(
    cube       = probs_cube,
    output_dir = OUTPUT_DIR,
    memsize    = MEMSIZE,
    multicores = MULTICORES,
    version    = "step1_smooth"
)
cat("  Done.\n\n")

# Label
cat("  Labeling...\n")
label_cube <- sits_label_classification(
    cube       = smooth_cube,
    output_dir = OUTPUT_DIR,
    version    = "step1_labels"
)
cat("  Done.\n\n")

saveRDS(label_cube, file.path(OUTPUT_DIR, "label_cube_step1.rds"))

cat("========================================\n")
cat("Step 1 Classification Complete!\n")
cat("========================================\n\n")

cat("Results in:", OUTPUT_DIR, "\n\n")
cat("Visualize:\n")
cat("  label_cube <- readRDS('", file.path(OUTPUT_DIR, "label_cube_step1.rds"), "')\n", sep = "")
cat("  plot(label_cube)\n\n")

cat("To download results:\n")
cat("  Export *_class.tif files from:", OUTPUT_DIR, "\n")

}
