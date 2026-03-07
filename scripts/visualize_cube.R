#!/usr/bin/env Rscript
# Visualize PlanetScope cube with cloud-masked data
# Creates RGB composites, time series plots, and band statistics

suppressPackageStartupMessages({
    library(sits)
    library(terra)
    library(ggplot2)
})

cat("========================================\n")
cat("PlanetScope Cube Visualization\n")
cat("========================================\n\n")

# Configuration
CUBE_FILE <- "data/cube_bands_indices_masked.rds"
OUTPUT_DIR <- "visualizations"

# Create output directory
if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
}

# ==============================================================================
# 1. Load the cube
# ==============================================================================

cat("Step 1: Loading cube...\n")

if (!file.exists(CUBE_FILE)) {
    cat("  ERROR: Cube file not found:", CUBE_FILE, "\n")
    cat("  Please run scripts/create_full_cube.R first\n")
    quit(status = 1)
}

cube <- readRDS(CUBE_FILE)

cat("  Cube loaded successfully\n")
cat("    Tiles:", nrow(cube), "\n")
cat("    Timeline:", length(sits_timeline(cube)), "dates\n")
cat("    Date range:", min(sits_timeline(cube)), "to", max(sits_timeline(cube)), "\n")
cat("    Bands:", paste(sits_bands(cube), collapse = ", "), "\n\n")

# ==============================================================================
# 2. Plot timeline
# ==============================================================================

cat("Step 2: Creating timeline plot...\n")

timeline <- sits_timeline(cube)
timeline_df <- data.frame(
    date = as.Date(timeline),
    index = seq_along(timeline)
)

p_timeline <- ggplot(timeline_df, aes(x = date, y = index)) +
    geom_point(size = 3, color = "steelblue") +
    geom_line(color = "steelblue", alpha = 0.5) +
    scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
    labs(
        title = "PlanetScope Image Timeline",
        subtitle = paste(nrow(timeline_df), "acquisition dates"),
        x = "Date",
        y = "Image Number"
    ) +
    theme_minimal() +
    theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        plot.title = element_text(face = "bold", size = 14),
        panel.grid.minor = element_blank()
    )

timeline_file <- file.path(OUTPUT_DIR, "timeline.png")
ggsave(timeline_file, p_timeline, width = 10, height = 5, dpi = 150)
cat("  Saved:", timeline_file, "\n\n")

# ==============================================================================
# 3. Temporal coverage analysis
# ==============================================================================

cat("Step 3: Analyzing temporal coverage...\n")

# Calculate time gaps between acquisitions
timeline_dates <- as.Date(timeline)
gaps <- diff(timeline_dates)

gap_stats <- data.frame(
    min_gap = min(gaps),
    max_gap = max(gaps),
    mean_gap = mean(gaps),
    median_gap = median(gaps)
)

cat("  Time gap statistics (days):\n")
cat("    Minimum:", gap_stats$min_gap, "\n")
cat("    Maximum:", gap_stats$max_gap, "\n")
cat("    Mean:", round(gap_stats$mean_gap, 1), "\n")
cat("    Median:", gap_stats$median_gap, "\n\n")

# Plot temporal gaps
gap_df <- data.frame(
    date_from = timeline_dates[-length(timeline_dates)],
    date_to = timeline_dates[-1],
    gap_days = as.numeric(gaps)
)

p_gaps <- ggplot(gap_df, aes(x = date_from, y = gap_days)) +
    geom_segment(aes(xend = date_to, yend = 0),
                 color = "darkred", linewidth = 1.5, alpha = 0.7) +
    geom_point(size = 3, color = "darkred") +
    scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
    labs(
        title = "Temporal Gaps Between Acquisitions",
        subtitle = paste("Mean gap:", round(gap_stats$mean_gap, 1), "days"),
        x = "Acquisition Date",
        y = "Gap to Next Image (days)"
    ) +
    theme_minimal() +
    theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        plot.title = element_text(face = "bold", size = 14),
        panel.grid.minor = element_blank()
    )

gaps_file <- file.path(OUTPUT_DIR, "temporal_gaps.png")
ggsave(gaps_file, p_gaps, width = 10, height = 5, dpi = 150)
cat("  Saved:", gaps_file, "\n\n")

# ==============================================================================
# 4. Sample random points and extract time series
# ==============================================================================

cat("Step 4: Extracting sample time series...\n")

# Create random sample points (10 points)
set.seed(42)

# Get first tile for CRS and bbox
first_tile <- cube[1, ]
cube_bbox <- sits:::.bbox(first_tile)
cube_crs <- sits:::.crs(first_tile)

# Generate random points within bbox (already in cube CRS coordinates)
n_samples <- 10
sample_points <- data.frame(
    longitude = runif(n_samples, cube_bbox$xmin, cube_bbox$xmax),
    latitude = runif(n_samples, cube_bbox$ymin, cube_bbox$ymax)
)

# Add required sits columns
sample_points$label <- paste0("Point_", 1:n_samples)
sample_points$start_date <- min(timeline)
sample_points$end_date <- max(timeline)

# Convert to sf object (using cube CRS directly)
sample_points <- sf::st_as_sf(sample_points,
                              coords = c("longitude", "latitude"),
                              crs = cube_crs)

# Extract time series
cat("  Extracting time series for", n_samples, "sample points...\n")
cat("  NOTE: Skipping time series extraction - cube is not regularized\n")
cat("  For time series analysis, run sits_regularize() first\n\n")

# Skip time series extraction for now
skip_ts <- TRUE

if (!skip_ts) {
tryCatch({
    samples <- sits_get_data(cube, sample_points)

    cat("  Successfully extracted", nrow(samples), "time series\n\n")

    # Plot NDVI time series
    if ("NDVI" %in% sits_bands(cube)) {
        cat("  Plotting NDVI time series...\n")

        p_ndvi <- plot(samples, bands = "NDVI") +
            labs(
                title = "NDVI Time Series - Sample Points",
                subtitle = paste(n_samples, "random locations")
            ) +
            theme_minimal() +
            theme(
                plot.title = element_text(face = "bold", size = 14),
                legend.position = "none"
            )

        ndvi_ts_file <- file.path(OUTPUT_DIR, "ndvi_timeseries.png")
        ggsave(ndvi_ts_file, p_ndvi, width = 12, height = 6, dpi = 150)
        cat("    Saved:", ndvi_ts_file, "\n")
    }

    # Plot NIR (B8) time series
    if ("B8" %in% sits_bands(cube)) {
        cat("  Plotting NIR time series...\n")

        p_nir <- plot(samples, bands = "B8") +
            labs(
                title = "NIR (Band 8) Time Series - Sample Points",
                subtitle = paste(n_samples, "random locations")
            ) +
            theme_minimal() +
            theme(
                plot.title = element_text(face = "bold", size = 14),
                legend.position = "none"
            )

        nir_ts_file <- file.path(OUTPUT_DIR, "nir_timeseries.png")
        ggsave(nir_ts_file, p_nir, width = 12, height = 6, dpi = 150)
        cat("    Saved:", nir_ts_file, "\n")
    }

    # Plot NDWI time series
    if ("NDWI" %in% sits_bands(cube)) {
        cat("  Plotting NDWI time series...\n")

        p_ndwi <- plot(samples, bands = "NDWI") +
            labs(
                title = "NDWI Time Series - Sample Points",
                subtitle = paste(n_samples, "random locations")
            ) +
            theme_minimal() +
            theme(
                plot.title = element_text(face = "bold", size = 14),
                legend.position = "none"
            )

        ndwi_ts_file <- file.path(OUTPUT_DIR, "ndwi_timeseries.png")
        ggsave(ndwi_ts_file, p_ndwi, width = 12, height = 6, dpi = 150)
        cat("    Saved:", ndwi_ts_file, "\n\n")
    }

}, error = function(e) {
    cat("  WARNING: Could not extract time series\n")
    cat("  Error:", conditionMessage(e), "\n\n")
})
}

# ==============================================================================
# 5. Visualize temporal statistics
# ==============================================================================

cat("Step 5: Visualizing temporal statistics...\n")

STATS_DIR <- "data/planetscope_index_stats_masked"

if (dir.exists(STATS_DIR)) {
    # Load NDVI statistics
    ndvi_max_file <- file.path(STATS_DIR, "NDVI_max.tif")
    ndvi_min_file <- file.path(STATS_DIR, "NDVI_min.tif")
    ndvi_std_file <- file.path(STATS_DIR, "NDVI_std.tif")

    if (all(file.exists(c(ndvi_max_file, ndvi_min_file, ndvi_std_file)))) {
        cat("  Creating NDVI statistics composite...\n")

        ndvi_max <- rast(ndvi_max_file)
        ndvi_min <- rast(ndvi_min_file)
        ndvi_std <- rast(ndvi_std_file)

        # Create RGB composite: R=max, G=median, B=min
        # High values = areas that get very green
        # Low values = always low vegetation
        ndvi_median_file <- file.path(STATS_DIR, "NDVI_median.tif")
        if (file.exists(ndvi_median_file)) {
            ndvi_median <- rast(ndvi_median_file)

            # Stack for RGB
            ndvi_rgb <- c(ndvi_max, ndvi_median, ndvi_min)

            # Write RGB composite
            rgb_file <- file.path(OUTPUT_DIR, "NDVI_temporal_RGB.tif")
            writeRaster(ndvi_rgb, rgb_file,
                       overwrite = TRUE,
                       gdal = c("COMPRESS=LZW", "PHOTOMETRIC=RGB"))
            cat("    Saved:", rgb_file, "\n")
            cat("      Red = NDVI max (peak vegetation)\n")
            cat("      Green = NDVI median (typical state)\n")
            cat("      Blue = NDVI min (minimum vegetation)\n\n")
        }

        # Plot NDVI variability (std)
        cat("  Creating NDVI variability map...\n")

        # Sample for plotting
        ndvi_std_sample <- spatSample(ndvi_std, size = 50000, method = "regular",
                                      xy = TRUE, as.df = TRUE)

        # Rename columns for ggplot
        colnames(ndvi_std_sample)[colnames(ndvi_std_sample) == "x"] <- "longitude"
        colnames(ndvi_std_sample)[colnames(ndvi_std_sample) == "y"] <- "latitude"

        p_std <- ggplot(ndvi_std_sample, aes(x = longitude, y = latitude, fill = NDVI_std)) +
            geom_raster() +
            scale_fill_viridis_c(option = "magma", name = "Std Dev") +
            coord_equal() +
            labs(
                title = "NDVI Temporal Variability",
                subtitle = "Standard deviation across all dates (high = dynamic, low = stable)",
                x = "Longitude",
                y = "Latitude"
            ) +
            theme_minimal() +
            theme(
                plot.title = element_text(face = "bold", size = 14),
                axis.text.x = element_text(angle = 45, hjust = 1)
            )

        std_file <- file.path(OUTPUT_DIR, "NDVI_variability.png")
        ggsave(std_file, p_std, width = 10, height = 8, dpi = 150)
        cat("    Saved:", std_file, "\n\n")
    }
} else {
    cat("  WARNING: Temporal statistics directory not found\n")
    cat("  Run scripts/create_index_statistics.R first\n\n")
}

# ==============================================================================
# 6. Create quick-look RGB composites from cube
# ==============================================================================

cat("Step 6: Creating RGB composite quick-looks from cube...\n")

RGB_DIR <- "data/planetscope_rgb_masked"

if (dir.exists(RGB_DIR)) {
    # Get first, middle, and last dates
    dates <- sits_timeline(cube)
    selected_dates <- c(
        dates[1],
        dates[length(dates) %/% 2],
        dates[length(dates)]
    )

    cat("  Selected dates for quick-look:\n")
    for (d in selected_dates) {
        cat("    -", as.character(as.Date(d)), "\n")
    }

    cat("\n  RGB composites available at:", RGB_DIR, "\n")
    cat("  Load in QGIS for visual inspection\n\n")
} else {
    cat("  WARNING: RGB directory not found\n")
    cat("  Run scripts/create_rgb_composites.R first\n\n")
}

# ==============================================================================
# 7. Summary
# ==============================================================================

cat("========================================\n")
cat("Visualization Complete!\n")
cat("========================================\n\n")

cat("Generated visualizations:\n")
cat("  - Timeline plot:", file.path(OUTPUT_DIR, "timeline.png"), "\n")
cat("  - Temporal gaps:", file.path(OUTPUT_DIR, "temporal_gaps.png"), "\n")

if (file.exists(file.path(OUTPUT_DIR, "ndvi_timeseries.png"))) {
    cat("  - NDVI time series:", file.path(OUTPUT_DIR, "ndvi_timeseries.png"), "\n")
    cat("  - NIR time series:", file.path(OUTPUT_DIR, "nir_timeseries.png"), "\n")
    cat("  - NDWI time series:", file.path(OUTPUT_DIR, "ndwi_timeseries.png"), "\n")
}

if (file.exists(file.path(OUTPUT_DIR, "NDVI_temporal_RGB.tif"))) {
    cat("  - NDVI temporal RGB:", file.path(OUTPUT_DIR, "NDVI_temporal_RGB.tif"), "\n")
    cat("  - NDVI variability:", file.path(OUTPUT_DIR, "NDVI_variability.png"), "\n")
}

cat("\nVisualization directory:", OUTPUT_DIR, "\n\n")

cat("Next steps:\n\n")

cat("1. View timeline and gap analysis:\n")
cat("   - Open PNG files in visualizations/\n")
cat("   - Check temporal coverage patterns\n\n")

cat("2. Examine time series:\n")
cat("   - Review NDVI/NDWI/NIR temporal patterns\n")
cat("   - Identify seasonal trends\n")
cat("   - Look for anomalies or disturbances\n\n")

cat("3. Load in QGIS for spatial analysis:\n")
cat("   # Temporal RGB composite\n")
cat("   - Add: visualizations/NDVI_temporal_RGB.tif\n")
cat("   - Interpret: Red = peak growth, Blue = minimum\n\n")

cat("   # Individual RGB dates\n")
cat("   - Add: data/planetscope_rgb_masked/*.tif\n")
cat("   - Animate through time series\n\n")

cat("   # Temporal statistics\n")
cat("   - Add: data/planetscope_index_stats_masked/*.tif\n")
cat("   - Use NDVI_std to identify areas of change\n\n")

cat("4. Prepare training samples:\n")
cat("   - Use visualizations to identify representative areas\n")
cat("   - Collect samples for each land cover class\n")
cat("   - Note temporal changes (forest -> bareland -> built-up)\n\n")

cat("Cube information:\n")
print(cube)
cat("\n")
