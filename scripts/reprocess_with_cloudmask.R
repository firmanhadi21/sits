#!/usr/bin/env Rscript
# Reprocess PlanetScope data with UDM2 cloud masking
# Step 1: Extract 8-band images and UDM2 masks
# Step 2: Apply cloud masks to set bad pixels to NoData
# Step 3: Ready for mosaicking

suppressPackageStartupMessages({
    library(terra)
})

cat("========================================\n")
cat("Reprocessing with Cloud Masking\n")
cat("========================================\n\n")

# Configuration
ZIP_DIR <- "data/planetscope"
OUTPUT_DIR <- "data/planetscope_cloudmasked"
TEMP_DIR <- file.path(OUTPUT_DIR, "temp")

# Create directories
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TEMP_DIR, recursive = TRUE, showWarnings = FALSE)

cat("Configuration:\n")
cat("  Input: ", ZIP_DIR, "\n")
cat("  Output:", OUTPUT_DIR, "\n\n")

# Get ZIP files
zip_files <- list.files(ZIP_DIR, pattern = "\\.zip$", full.names = TRUE)
cat("Found", length(zip_files), "ZIP files\n\n")

processed_count <- 0
masked_count <- 0

for (zip_file in zip_files) {
    cat("Processing:", basename(zip_file), "\n")

    # List contents
    file_list <- unzip(zip_file, list = TRUE)

    # Find 8-band and UDM2 files
    band8_files <- grep("AnalyticMS_SR_8b_harmonized.*\\.tif$", file_list$Name, value = TRUE)
    udm2_files <- grep("udm2.*\\.tif$", file_list$Name, value = TRUE)

    cat("  8-band images:", length(band8_files), "\n")
    cat("  UDM2 masks:   ", length(udm2_files), "\n")

    if (length(band8_files) == 0) {
        cat("  WARNING: No 8-band images found\n\n")
        next
    }

    # Extract files to temp directory
    cat("  Extracting files...\n")
    unzip(zip_file, files = c(band8_files, udm2_files),
          exdir = TEMP_DIR, junkpaths = TRUE)

    # Process each 8-band image
    for (band8_file in band8_files) {
        band8_basename <- basename(band8_file)
        band8_path <- file.path(TEMP_DIR, band8_basename)

        # Find corresponding UDM2
        # Pattern: same date/time prefix
        prefix <- sub("_AnalyticMS_SR_8b_harmonized.*", "", band8_basename)
        udm2_basename <- paste0(prefix, "_udm2_clip.tif")
        udm2_path <- file.path(TEMP_DIR, udm2_basename)

        if (!file.exists(udm2_path)) {
            cat("    WARNING: No UDM2 found for", band8_basename, "\n")
            cat("             Copying without cloud masking...\n")

            # Split into bands without masking
            r <- rast(band8_path)
            for (b in 1:8) {
                output_file <- file.path(OUTPUT_DIR,
                    sub("\\.tif$", sprintf("_B%d.tif", b), band8_basename))
                writeRaster(r[[b]], output_file,
                           overwrite = TRUE,
                           gdal = c("COMPRESS=LZW"))
            }
            processed_count <- processed_count + 1
            next
        }

        cat("    Applying cloud mask to", band8_basename, "\n")

        # Load rasters
        r_8band <- rast(band8_path)
        r_udm2 <- rast(udm2_path)

        # Check if extents match
        if (!compareGeom(r_8band, r_udm2, stopOnError = FALSE)) {
            cat("      Resampling UDM2 to match 8-band image...\n")
            r_udm2 <- resample(r_udm2, r_8band, method = "near")
        }

        # Create cloud mask
        # Good pixel = clear AND no cloud AND no heavy haze AND no shadow AND usable
        clear_band <- r_udm2[[1]]        # 0=clear, 1=not clear
        shadow_band <- r_udm2[[3]]       # 0=no shadow, 1=shadow
        heavy_haze_band <- r_udm2[[5]]   # 0=no haze, 1=heavy haze
        cloud_band <- r_udm2[[6]]        # 0=no cloud, 1=cloud
        unusable_band <- r_udm2[[8]]     # 0=usable, 1=unusable

        # Create mask: 1=good, 0=bad
        good_pixel <- (clear_band == 0) &
                     (cloud_band == 0) &
                     (heavy_haze_band == 0) &
                     (shadow_band == 0) &
                     (unusable_band == 0)

        # Calculate cloud-free percentage
        total_pixels <- ncell(good_pixel)
        good_pixels <- sum(values(good_pixel), na.rm = TRUE)
        good_percent <- 100 * good_pixels / total_pixels

        cat("      Cloud-free pixels:", sprintf("%.1f%%\n", good_percent))

        # Apply mask to each band - set bad pixels to NA
        for (b in 1:8) {
            band_data <- r_8band[[b]]

            # Set masked pixels to NA
            band_data[!good_pixel] <- NA

            # Output filename
            output_file <- file.path(OUTPUT_DIR,
                sub("\\.tif$", sprintf("_B%d.tif", b), band8_basename))

            # Write with NoData value
            writeRaster(band_data, output_file,
                       overwrite = TRUE,
                       NAflag = 0,  # Use 0 as NoData value
                       datatype = "INT2U",
                       gdal = c("COMPRESS=LZW"))
        }

        masked_count <- masked_count + 1
    }

    # Clean up temp files
    unlink(file.path(TEMP_DIR, basename(c(band8_files, udm2_files))))

    processed_count <- processed_count + length(band8_files)
    cat("\n")
}

# Clean up temp directory
unlink(TEMP_DIR, recursive = TRUE)

cat("========================================\n")
cat("Cloud Masking Complete!\n")
cat("========================================\n\n")

cat("Results:\n")
cat("  Total images processed:", processed_count, "\n")
cat("  Images with cloud masking:", masked_count, "\n")
cat("  Output directory:", OUTPUT_DIR, "\n\n")

# Count output files
output_files <- list.files(OUTPUT_DIR, pattern = "_B[1-8]\\.tif$")
cat("  Output files:", length(output_files), "band files\n")
cat("  (", length(output_files) / 8, "images ×  8 bands )\n\n")

cat("Next steps:\n\n")

cat("1. Create mosaics from cloud-masked tiles:\n")
cat("   # Update mosaic_by_date.R to use cloudmasked data\n")
cat("   DATA_DIR <- 'data/planetscope_cloudmasked'\n")
cat("   OUTPUT_DIR <- 'data/planetscope_mosaicked_masked'\n")
cat("   Rscript scripts/mosaic_by_date.R\n\n")

cat("2. Calculate indices from cloud-masked mosaics:\n")
cat("   # Update create_index_composites.R\n")
cat("   INPUT_DIR <- 'data/planetscope_mosaicked_masked'\n")
cat("   OUTPUT_DIR <- 'data/planetscope_indices_masked'\n")
cat("   Rscript scripts/create_index_composites.R\n\n")

cat("3. Calculate temporal statistics:\n")
cat("   # Automatically handles NoData - only uses valid pixels per date\n")
cat("   # If dates 17-18 have clouds at pixel X, statistics use 17 dates for that pixel\n")
cat("   INPUT_DIR <- 'data/planetscope_indices_masked'\n")
cat("   OUTPUT_DIR <- 'data/planetscope_index_stats_masked'\n")
cat("   Rscript scripts/create_index_statistics.R\n\n")

cat("Notes:\n")
cat("- Cloud/haze/shadow pixels are set to NoData (0)\n")
cat("- Mosaicking will handle NoData automatically\n")
cat("- Temporal statistics use only valid pixels per date\n")
cat("- Each pixel may have different number of valid observations\n\n")
