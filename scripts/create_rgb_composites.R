#!/usr/bin/env Rscript
# Create true color RGB composites for each date
# Uses Band 6 (Red), Band 4 (Green), Band 2 (Blue)

cat("========================================\n")
cat("Creating RGB True Color Composites\n")
cat("========================================\n\n")

# Configuration
INPUT_DIR <- "data/planetscope_mosaicked_masked"  # Using cloud-masked mosaics
OUTPUT_DIR <- "data/planetscope_rgb_masked"  # Output with cloud masking

# Create output directory
if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
    cat("Created output directory:", OUTPUT_DIR, "\n\n")
}

# Get all B1 files to identify dates
b1_files <- list.files(INPUT_DIR, pattern = "_B1\\.tif$", full.names = FALSE)
dates <- sub("^([0-9]{8})_.*", "\\1", b1_files)
unique_dates <- unique(dates)
unique_dates <- sort(unique_dates)

cat("Found", length(unique_dates), "dates to process\n")
cat("Date range:", unique_dates[1], "to", unique_dates[length(unique_dates)], "\n\n")

# Process each date
success_count <- 0
fail_count <- 0

for (date in unique_dates) {
    cat("Processing", date, "...\n")

    # Find band files for this date (mosaicked files are named: DATE_BX.tif)
    b6_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_B6\\.tif$"), full.names = TRUE)
    b4_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_B4\\.tif$"), full.names = TRUE)
    b2_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_B2\\.tif$"), full.names = TRUE)

    # Check if all bands exist
    if (length(b6_file) == 0 || length(b4_file) == 0 || length(b2_file) == 0) {
        cat("  ERROR: Missing bands for", date, "\n")
        fail_count <- fail_count + 1
        next
    }

    # Output filename
    output_file <- file.path(OUTPUT_DIR, paste0(date, "_RGB.tif"))

    if (file.exists(output_file)) {
        cat("  Skipping (already exists):", basename(output_file), "\n")
        success_count <- success_count + 1
        next
    }

    # Create RGB composite using gdal_merge.py
    # Band order: Red (B6), Green (B4), Blue (B2)
    cmd <- sprintf(
        "gdal_merge.py -separate -o %s -co COMPRESS=LZW -co PHOTOMETRIC=RGB %s %s %s 2>&1",
        shQuote(output_file),
        shQuote(b6_file[1]),
        shQuote(b4_file[1]),
        shQuote(b2_file[1])
    )

    # Execute command
    result <- system(cmd, intern = TRUE)

    # Check if successful
    if (file.exists(output_file)) {
        # Get file size
        file_size <- file.info(output_file)$size / (1024^2)  # MB
        cat("  Created:", basename(output_file), sprintf("(%.1f MB)\n", file_size))
        success_count <- success_count + 1
    } else {
        cat("  ERROR: Failed to create RGB for", date, "\n")
        cat("  ", paste(result, collapse = "\n  "), "\n")
        fail_count <- fail_count + 1
    }
}

cat("\n========================================\n")
cat("RGB Composite Creation Complete!\n")
cat("========================================\n\n")

cat("Results:\n")
cat("  Successful:", success_count, "/", length(unique_dates), "\n")
cat("  Failed:", fail_count, "\n")
cat("  Output directory:", OUTPUT_DIR, "\n\n")

# List output files
rgb_files <- list.files(OUTPUT_DIR, pattern = "_RGB\\.tif$", full.names = FALSE)
if (length(rgb_files) > 0) {
    cat("Created RGB composites:\n")
    for (f in sort(rgb_files)) {
        # Convert date to readable format
        date_str <- sub("_RGB\\.tif$", "", f)
        readable_date <- format(as.Date(date_str, format = "%Y%m%d"), "%B %d, %Y")
        cat("  ", f, " (", readable_date, ")\n", sep = "")
    }
    cat("\n")
}

cat("Next steps:\n")
cat("1. Open in QGIS:\n")
cat("   - Add Raster Layer\n")
cat("   - Navigate to:", OUTPUT_DIR, "\n")
cat("   - Load RGB composites\n\n")

cat("2. Adjust visualization (if needed):\n")
cat("   - Right-click layer > Properties > Symbology\n")
cat("   - Adjust min/max values for better contrast\n")
cat("   - Try 2% cumulative count cut for auto-stretch\n\n")

cat("3. Create temporal animation:\n")
cat("   - Temporal Controller panel\n")
cat("   - Set date format to match filenames\n")
cat("   - Animate through time series\n\n")
