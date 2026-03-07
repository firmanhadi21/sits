#!/usr/bin/env Rscript
# Create sits cube with original bands AND pre-calculated indices

suppressPackageStartupMessages({
    library(sits)
})

cat("========================================\n")
cat("Creating Full Sits Cube\n")
cat("Band + Indices Combined\n")
cat("========================================\n\n")

# Configuration
BAND_DIR <- "data/planetscope_mosaicked_masked"  # Using cloud-masked mosaics
INDEX_DIR <- "data/planetscope_indices_masked"  # Using cloud-masked indices

# Note: sits requires files to have tile identifier
# We'll create a combined directory with proper naming (DATE_TILE_BAND.tif)
cat("Creating combined cube with bands + indices...\n\n")

# Copy band files and index files to a combined directory
COMBINED_DIR <- "data/planetscope_combined_masked"  # Combined cloud-masked data
if (!dir.exists(COMBINED_DIR)) {
    dir.create(COMBINED_DIR, recursive = TRUE)
}

cat("  Step 1: Organizing files for combined cube...\n")

# Get all dates
band_files <- list.files(BAND_DIR, pattern = "_B1\\.tif$", full.names = FALSE)
dates <- sub("^([0-9]{8})_.*", "\\1", band_files)
unique_dates <- unique(dates)
unique_dates <- sort(unique_dates)

cat("    Found", length(unique_dates), "dates\n")

# Create symbolic links for bands and indices
indices <- c("NDVI", "NDWI", "NDRE", "EVI", "SAVI", "GNDVI", "BSI", "NDTI")

# Link original bands (mosaicked files are named: DATE_BX.tif)
for (date in unique_dates) {
    for (band in c("B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8")) {
        src_file <- list.files(BAND_DIR,
                              pattern = paste0("^", date, "_", band, "\\.tif$"),
                              full.names = TRUE)[1]
        if (length(src_file) > 0 && !is.na(src_file)) {
            dst_file <- file.path(COMBINED_DIR, paste0(date, "_TILE_", band, ".tif"))
            if (!file.exists(dst_file)) {
                file.symlink(src_file, dst_file)
            }
        }
    }
}

# Link indices
for (date in unique_dates) {
    for (index in indices) {
        src_file <- file.path(INDEX_DIR, index, paste0(date, "_", index, ".tif"))
        if (file.exists(src_file)) {
            dst_file <- file.path(COMBINED_DIR, paste0(date, "_TILE_", index, ".tif"))
            if (!file.exists(dst_file)) {
                file.symlink(src_file, dst_file)
            }
        }
    }
}

cat("    Linked files to", COMBINED_DIR, "\n\n")

# Create combined cube
cat("  Step 2: Creating combined sits cube...\n")

all_bands <- c("B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", indices)

cube_combined <- sits_cube(
    source = "PLANET",
    collection = "MOSAIC-8B",
    data_dir = COMBINED_DIR,
    parse_info = c("date", "tile", "band"),
    delim = "_",
    bands = all_bands
)

cat("\n  Combined cube created:\n")
cat("    Tiles:", nrow(cube_combined), "\n")
cat("    Timeline:", length(sits_timeline(cube_combined)), "dates\n")
cat("    Date range:", min(sits_timeline(cube_combined)), "to", max(sits_timeline(cube_combined)), "\n")
cat("    Bands:", paste(sits_bands(cube_combined), collapse = ", "), "\n\n")

cat("========================================\n")
cat("Cube Creation Complete!\n")
cat("========================================\n\n")

cat("Summary:\n")
cat("  Combined cube:", length(all_bands), "bands (8 original + 8 indices)\n")
cat("  Data directory:", COMBINED_DIR, "\n\n")

cat("Usage examples:\n\n")

cat("1. Load combined cube (bands + indices):\n")
cat("   cube <- sits_cube(\n")
cat("       source = 'PLANET',\n")
cat("       collection = 'MOSAIC-8B',\n")
cat("       data_dir = 'data/planetscope_combined_masked',\n")
cat("       parse_info = c('date', 'tile', 'band'),\n")
cat("       delim = '_',\n")
cat("       bands = c('B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8',\n")
cat("                 'NDVI', 'NDWI', 'NDRE', 'EVI', 'SAVI', 'GNDVI', 'BSI', 'NDTI')\n")
cat("   )\n\n")

cat("2. Load specific bands/indices only:\n")
cat("   cube <- sits_cube(\n")
cat("       source = 'PLANET',\n")
cat("       collection = 'MOSAIC-8B',\n")
cat("       data_dir = 'data/planetscope_combined_masked',\n")
cat("       parse_info = c('date', 'tile', 'band'),\n")
cat("       delim = '_',\n")
cat("       bands = c('B6', 'B8', 'NDVI', 'NDWI', 'NDRE')  # Red, NIR, and key indices\n")
cat("   )\n\n")

cat("Benefits of combined cube:\n")
cat("  - Use all 16 features for classification\n")
cat("  - Better class separation (indices + raw bands)\n")
cat("  - No regularization needed for supervised classification\n")
cat("  - Direct time series analysis with sits_train/sits_classify\n\n")

cat("Next steps:\n")
cat("1. Extract training samples:\n")
cat("   samples <- sits_get_data(cube, training_points)\n\n")

cat("2. Train classification model:\n")
cat("   model <- sits_train(samples, sits_rfor())\n\n")

cat("3. Classify the cube:\n")
cat("   classified <- sits_classify(cube, model)\n\n")

# Save cube information
saveRDS(cube_combined, "data/cube_bands_indices_masked.rds")

cat("Cube saved:\n")
cat("  - data/cube_bands_indices_masked.rds\n\n")

cat("Load saved cube:\n")
cat("  cube <- readRDS('data/cube_bands_indices_masked.rds')\n\n")
