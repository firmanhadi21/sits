#!/usr/bin/env Rscript
# Create temporal statistics for spectral indices
# Generates min, max, median, and standard deviation across all dates

suppressPackageStartupMessages({
    library(terra)
})

cat("========================================\n")
cat("Creating Temporal Index Statistics\n")
cat("========================================\n\n")

# Configuration
INDEX_DIR <- "data/planetscope_indices"
OUTPUT_DIR <- "data/planetscope_index_stats"

# Indices to process
INDICES <- c("NDVI", "NDWI", "NDRE", "EVI", "SAVI", "GNDVI", "BSI", "NDTI")

# Statistics to calculate
STATISTICS <- c("min", "max", "median", "std")

# Create output directory
if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
}

cat("Configuration:\n")
cat("  Input directory:", INDEX_DIR, "\n")
cat("  Output directory:", OUTPUT_DIR, "\n")
cat("  Indices:", paste(INDICES, collapse = ", "), "\n")
cat("  Statistics:", paste(STATISTICS, collapse = ", "), "\n\n")

# Process each index
results <- data.frame(
    index = character(),
    stat = character(),
    output_file = character(),
    file_size_mb = numeric(),
    stringsAsFactors = FALSE
)

for (index in INDICES) {
    cat("Processing", index, "...\n")

    # Get all files for this index
    index_path <- file.path(INDEX_DIR, index)
    index_files <- list.files(index_path, pattern = "\\.tif$", full.names = TRUE)
    index_files <- sort(index_files)

    if (length(index_files) == 0) {
        cat("  WARNING: No files found for", index, "\n\n")
        next
    }

    cat("  Found", length(index_files), "dates\n")

    # Load all dates as a multi-layer raster
    cat("  Loading rasters...\n")

    # Load first raster to get initial extent
    first_rast <- rast(index_files[1])
    common_extent <- ext(first_rast)

    # Find common extent (intersection of all rasters)
    cat("  Finding common extent...\n")
    for (f in index_files[-1]) {
        r <- rast(f)
        common_extent <- intersect(common_extent, ext(r))
    }

    cat("    Common extent:", as.vector(common_extent), "\n")

    # Load and crop all rasters to common extent
    cat("  Cropping rasters to common extent...\n")
    raster_list <- list()
    for (i in seq_along(index_files)) {
        r <- rast(index_files[i])
        r_cropped <- crop(r, common_extent)
        raster_list[[i]] <- r_cropped
    }

    # Stack all cropped rasters
    index_stack <- rast(raster_list)
    names(index_stack) <- basename(index_files)

    cat("    Stack dimensions:", nrow(index_stack), "x", ncol(index_stack),
        "x", nlyr(index_stack), "layers\n")

    # Calculate statistics
    for (stat in STATISTICS) {
        cat("  Calculating", stat, "...\n")

        # Calculate statistic
        if (stat == "min") {
            stat_raster <- min(index_stack, na.rm = TRUE)
        } else if (stat == "max") {
            stat_raster <- max(index_stack, na.rm = TRUE)
        } else if (stat == "median") {
            stat_raster <- median(index_stack, na.rm = TRUE)
        } else if (stat == "std") {
            stat_raster <- stdev(index_stack, na.rm = TRUE)
        }

        # Set layer name
        names(stat_raster) <- paste0(index, "_", stat)

        # Output filename
        output_file <- file.path(OUTPUT_DIR, paste0(index, "_", stat, ".tif"))

        # Write raster
        writeRaster(stat_raster, output_file,
                   overwrite = TRUE,
                   datatype = "FLT4S",
                   gdal = c("COMPRESS=LZW"))

        # Get file size
        file_size_mb <- file.info(output_file)$size / (1024^2)

        # Record result
        results <- rbind(results, data.frame(
            index = index,
            stat = stat,
            output_file = basename(output_file),
            file_size_mb = file_size_mb,
            stringsAsFactors = FALSE
        ))

        cat("    Saved:", basename(output_file),
            sprintf("(%.1f MB)\n", file_size_mb))
    }

    cat("\n")
}

cat("========================================\n")
cat("Temporal Statistics Complete!\n")
cat("========================================\n\n")

# Summary
total_files <- nrow(results)
total_size_mb <- sum(results$file_size_mb)

cat("Summary:\n")
cat("  Files created:", total_files, "\n")
cat("  Total size:", sprintf("%.1f MB (%.2f GB)\n",
                             total_size_mb, total_size_mb / 1024))
cat("  Output directory:", OUTPUT_DIR, "\n\n")

# Summary by statistic
cat("Files per statistic:\n")
for (stat in STATISTICS) {
    stat_count <- sum(results$stat == stat)
    cat(sprintf("  %-8s: %d files\n", stat, stat_count))
}
cat("\n")

# Summary by index
cat("Statistics per index:\n")
for (index in INDICES) {
    index_count <- sum(results$index == index)
    if (index_count > 0) {
        cat(sprintf("  %-8s: %d statistics\n", index, index_count))
    }
}
cat("\n")

cat("File naming convention:\n")
cat("  <INDEX>_<STATISTIC>.tif\n")
cat("  Examples:\n")
cat("    NDVI_min.tif     - Minimum NDVI across all dates\n")
cat("    NDVI_max.tif     - Maximum NDVI across all dates\n")
cat("    NDVI_median.tif  - Median NDVI across all dates\n")
cat("    NDVI_std.tif     - Standard deviation of NDVI\n\n")

cat("Interpretation:\n")
cat("  min:    Minimum value across time (lowest vegetation, driest, etc.)\n")
cat("  max:    Maximum value across time (peak vegetation, wettest, etc.)\n")
cat("  median: Central tendency, less affected by outliers than mean\n")
cat("  std:    Temporal variability (high = dynamic, low = stable)\n\n")

cat("Use cases:\n\n")

cat("1. Identify stable vs. dynamic areas:\n")
cat("   - Low std = stable land cover (forest, water, built-up)\n")
cat("   - High std = dynamic land cover (agriculture, seasonal water)\n\n")

cat("2. Seasonal characterization:\n")
cat("   - max NDVI = peak growing season\n")
cat("   - min NDVI = senescence or harvest period\n")
cat("   - median NDVI = typical vegetation state\n\n")

cat("3. Change detection:\n")
cat("   - Compare min/max before and after dam construction\n")
cat("   - Use std to identify areas with change\n\n")

cat("4. Land cover discrimination:\n")
cat("   - Natural forest: high median NDVI, low std\n")
cat("   - Cropland: moderate median NDVI, high std\n")
cat("   - Bareland: low median NDVI, low std (stable bare)\n")
cat("   - Water: high median NDWI, low std\n\n")

cat("Visualization in QGIS:\n")
cat("1. Load statistics:\n")
cat("   Layer → Add Raster Layer → data/planetscope_index_stats/\n\n")

cat("2. Style recommendations:\n\n")

cat("   NDVI statistics:\n")
cat("   - min/max/median: RdYlGn (Red-Yellow-Green), range 0-1\n")
cat("   - std: Spectral (blue to red), range 0-0.3\n\n")

cat("   NDWI statistics:\n")
cat("   - min/max/median: Blues, range -0.5 to 0.5\n")
cat("   - std: Spectral, range 0-0.3\n\n")

cat("   std (all indices):\n")
cat("   - High values (red) = dynamic/changing areas\n")
cat("   - Low values (blue) = stable areas\n\n")

cat("3. Create RGB composites:\n")
cat("   Red:   NDVI_max (peak vegetation)\n")
cat("   Green: NDVI_median (typical state)\n")
cat("   Blue:  NDVI_min (minimum vegetation)\n\n")

cat("4. Identify dam impact:\n")
cat("   - Load NDVI_std\n")
cat("   - High std values = areas with change\n")
cat("   - Cross-reference with RGB composites from different years\n\n")

# Save summary
summary_file <- file.path(OUTPUT_DIR, "statistics_summary.csv")
write.csv(results, summary_file, row.names = FALSE)
cat("Summary saved to:", summary_file, "\n\n")

cat("Next steps:\n")
cat("1. Open QGIS and load statistics from:", OUTPUT_DIR, "\n")
cat("2. Compare min/max to understand temporal range\n")
cat("3. Use std to identify areas of change\n")
cat("4. Combine statistics for multi-temporal analysis\n\n")
