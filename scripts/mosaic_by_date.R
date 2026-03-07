#!/usr/bin/env Rscript
# Mosaic PlanetScope tiles by date
# Combines multiple scenes from the same date into a single mosaic

# No R packages needed - using GDAL directly

cat("========================================\n")
cat("PlanetScope Date Mosaicking\n")
cat("========================================\n\n")

# ==============================================================================
# Configuration
# ==============================================================================

INPUT_DIR <- "data/planetscope_processed"
OUTPUT_DIR <- "data/planetscope_mosaicked"

# Bands to process
BANDS <- c("B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8")

# ==============================================================================
# Step 1: Identify unique dates
# ==============================================================================

cat("Step 1: Analyzing data structure...\n")

# Get all B1 files (we'll use this to identify dates)
b1_files <- list.files(INPUT_DIR, pattern = "_B1\\.tif$", full.names = TRUE)

# Extract dates from filenames
dates <- sub("^(\\d{8})_.*", "\\1", basename(b1_files))
unique_dates <- unique(dates)
unique_dates <- sort(unique_dates)

cat("  Found", length(b1_files), "scenes across", length(unique_dates), "dates\n\n")

# Count scenes per date
date_counts <- table(dates)
cat("  Scenes per date:\n")
for (date in unique_dates) {
    count <- date_counts[date]
    cat("    ", date, ":", count, "scene(s)\n")
}
cat("\n")

# ==============================================================================
# Step 2: Create output directory
# ==============================================================================

if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
}

# ==============================================================================
# Step 3: Mosaic by date
# ==============================================================================

cat("Step 2: Mosaicking scenes by date...\n\n")

for (date in unique_dates) {
    cat("  Processing date:", date, "\n")

    # Get all files for this date
    date_files <- b1_files[dates == date]
    n_scenes <- length(date_files)

    cat("    Found", n_scenes, "scene(s)\n")

    # Process each band
    for (band in BANDS) {
        # Get files for this band
        band_pattern <- paste0("_", band, "\\.tif$")
        band_files <- sub("_B1\\.tif$", paste0("_", band, ".tif"), date_files)

        # Check all files exist
        existing_files <- band_files[file.exists(band_files)]

        if (length(existing_files) == 0) {
            cat("      WARNING: No files found for", band, "\n")
            next
        }

        # Output filename
        output_file <- file.path(OUTPUT_DIR, paste0(date, "_", band, ".tif"))

        if (!file.exists(output_file)) {
            if (length(existing_files) == 1) {
                # Single file - just copy
                file.copy(existing_files[1], output_file)
            } else {
                # Multiple files - mosaic using GDAL
                # Build gdal_merge command
                files_str <- paste(shQuote(existing_files), collapse = " ")

                # Use gdal_merge.py for mosaicking
                cmd <- sprintf(
                    "gdal_merge.py -o %s -co COMPRESS=LZW -ot UInt16 %s 2>/dev/null",
                    shQuote(output_file),
                    files_str
                )

                # Execute
                exit_code <- system(cmd)

                if (exit_code != 0) {
                    cat("      WARNING: gdal_merge failed for", band, "\n")
                }
            }
        }
    }

    cat("    ", ifelse(n_scenes > 1, "Mosaicked", "Copied"), "all bands\n\n")
}

# ==============================================================================
# Step 4: Summary
# ==============================================================================

cat("========================================\n")
cat("Mosaicking Complete!\n")
cat("========================================\n\n")

# Count output files
output_files <- list.files(OUTPUT_DIR, pattern = "\\.tif$")
output_dates <- length(unique(sub("_(B[0-9])\\.tif$", "", output_files)))

cat("Results:\n")
cat("  Input:  ", length(b1_files), "scenes\n")
cat("  Output: ", output_dates, "dates ×", length(BANDS), "bands =", length(output_files), "files\n")
cat("  Location:", OUTPUT_DIR, "\n\n")

cat("Output file structure:\n")
cat("  YYYYMMDD_B1.tif\n")
cat("  YYYYMMDD_B2.tif\n")
cat("  ...\n")
cat("  YYYYMMDD_B8.tif\n\n")

cat("Next steps:\n\n")

cat("1. Verify mosaics in QGIS:\n")
cat("   - Load mosaics from:", OUTPUT_DIR, "\n")
cat("   - Check for seamless coverage\n\n")

cat("2. Create sits cube from mosaics:\n")
cat("   DATA_DIR <- '", OUTPUT_DIR, "'\n", sep = "")
cat("   \n")
cat("   cube <- sits_cube(\n")
cat("       source = 'BDC',\n")
cat("       collection = 'PLANET-MOSAIC',\n")
cat("       data_dir = DATA_DIR,\n")
cat("       parse_info = c('date', 'band'),\n")
cat("       delim = '_'\n")
cat("   )\n\n")

cat("3. Run unsupervised clustering:\n")
cat("   # Update unsupervised_clustering.R to use mosaicked data\n")
cat("   DATA_DIR <- '", OUTPUT_DIR, "'\n", sep = "")
cat("   Rscript scripts/unsupervised_clustering.R\n\n")

cat("4. Or proceed directly to classification:\n")
cat("   # Update classify_planetscope.R\n")
cat("   Rscript scripts/classify_planetscope.R\n\n")

# Print dates for reference
cat("Available dates:\n")
for (date in unique_dates) {
    formatted_date <- as.Date(date, format = "%Y%m%d")
    cat("  ", date, "(", format(formatted_date, "%B %d, %Y"), ")\n")
}
cat("\n")
