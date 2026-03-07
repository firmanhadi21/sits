#!/usr/bin/env Rscript
# Calculate temporal summary statistics for time series classification
# This creates features like mean, min, max, std, range for each band/index

#' Add temporal summary statistics to training samples
#'
#' This function calculates statistical summaries (mean, min, max, std, etc.)
#' from time series data. These features can improve classification accuracy
#' and are more robust to irregular sampling.
#'
#' For example, "Natural Forest has high stable NDVI" becomes:
#'   - NDVI_mean: 0.85
#'   - NDVI_std: 0.05 (low = stable)
#'   - NDVI_min: 0.80
#'   - NDVI_max: 0.90
#'
#' @param samples Time series samples (from sits_get_data)
#' @param stats Character vector of statistics to calculate
#'              Options: "mean", "min", "max", "std", "median", "range", "cv", "amplitude"
#' @return Modified samples with temporal features added
#' @export
add_temporal_features <- function(samples,
                                  stats = c("mean", "std", "min", "max", "amplitude")) {

    cat("Adding temporal summary statistics...\n")
    cat("  Statistics:", paste(stats, collapse = ", "), "\n")

    # Get band names
    bands <- names(samples$time_series[[1]])[-1]  # Exclude "Index" column
    cat("  Bands/Indices:", paste(bands, collapse = ", "), "\n")

    # Calculate statistics for each sample
    for (i in seq_len(nrow(samples))) {
        ts <- samples$time_series[[i]]

        for (band in bands) {
            values <- ts[[band]]

            # Remove NA values
            values <- values[!is.na(values)]

            if (length(values) == 0) {
                # No valid values - set all stats to NA
                for (stat in stats) {
                    col_name <- paste0(band, "_", stat)
                    samples[[col_name]][i] <- NA
                }
                next
            }

            # Calculate each statistic
            for (stat in stats) {
                col_name <- paste0(band, "_", stat)

                stat_value <- switch(stat,
                    "mean" = mean(values, na.rm = TRUE),
                    "min" = min(values, na.rm = TRUE),
                    "max" = max(values, na.rm = TRUE),
                    "std" = sd(values, na.rm = TRUE),
                    "median" = median(values, na.rm = TRUE),
                    "range" = max(values, na.rm = TRUE) - min(values, na.rm = TRUE),
                    "cv" = sd(values, na.rm = TRUE) / mean(values, na.rm = TRUE),  # Coefficient of variation
                    "amplitude" = (max(values, na.rm = TRUE) - min(values, na.rm = TRUE)) / 2,
                    stop("Unknown statistic: ", stat)
                )

                samples[[col_name]][i] <- stat_value
            }
        }
    }

    # Count features added
    n_features <- length(bands) * length(stats)
    cat("  Added", n_features, "temporal features\n\n")

    return(samples)
}

#' Calculate temporal features for classification
#'
#' Wrapper function that adds temporal statistics and creates a feature table
#' suitable for classification algorithms
#'
#' @param samples Time series samples
#' @param use_time_series Boolean - keep original time series (TRUE) or use only stats (FALSE)
#' @return Samples with temporal features
#' @export
prepare_temporal_features <- function(samples, use_time_series = TRUE) {

    cat("========================================\n")
    cat("Temporal Feature Preparation\n")
    cat("========================================\n\n")

    # Add temporal statistics
    samples_with_stats <- add_temporal_features(
        samples,
        stats = c("mean", "std", "min", "max", "amplitude")
    )

    if (!use_time_series) {
        cat("Removing original time series (using only statistics)...\n")
        # Keep only statistical features, remove time series
        samples_with_stats$time_series <- NULL
        cat("  Classification will use only temporal statistics\n\n")
    } else {
        cat("Keeping original time series + statistics\n")
        cat("  Classification will use both raw time series and statistics\n\n")
    }

    # Print feature summary
    feature_cols <- names(samples_with_stats)[grepl("_mean$|_std$|_min$|_max$|_amplitude$",
                                                     names(samples_with_stats))]

    cat("Temporal features created:\n")
    cat("  Total statistical features:", length(feature_cols), "\n")

    if (use_time_series) {
        n_dates <- nrow(samples_with_stats$time_series[[1]])
        n_bands <- ncol(samples_with_stats$time_series[[1]]) - 1  # Exclude Index column
        cat("  Time series features:", n_dates, "dates ×", n_bands, "bands =", n_dates * n_bands, "\n")
        cat("  TOTAL FEATURES:", length(feature_cols) + (n_dates * n_bands), "\n\n")
    } else {
        cat("  TOTAL FEATURES:", length(feature_cols), "\n\n")
    }

    return(samples_with_stats)
}

#' Show temporal feature differences between classes
#'
#' This function helps understand which temporal statistics best discriminate
#' between your classes
#'
#' @param samples Samples with temporal features
#' @param band Band/index to analyze (e.g., "NDVI", "EVI")
#' @export
compare_temporal_features <- function(samples, band = "NDVI") {

    cat("========================================\n")
    cat("Temporal Feature Comparison:", band, "\n")
    cat("========================================\n\n")

    # Get unique classes
    classes <- unique(samples$label)

    # Statistics to show
    stats <- c("mean", "std", "min", "max", "amplitude")

    # Create comparison table
    cat(sprintf("%-20s", "Class"))
    for (stat in stats) {
        cat(sprintf("%12s", paste0(stat)))
    }
    cat("\n")
    cat(strrep("-", 20 + 12 * length(stats)), "\n")

    for (class_name in classes) {
        class_samples <- samples[samples$label == class_name, ]

        cat(sprintf("%-20s", class_name))

        for (stat in stats) {
            col_name <- paste0(band, "_", stat)
            if (col_name %in% names(class_samples)) {
                value <- mean(class_samples[[col_name]], na.rm = TRUE)
                cat(sprintf("%12.3f", value))
            } else {
                cat(sprintf("%12s", "N/A"))
            }
        }
        cat("\n")
    }
    cat("\n")

    # Interpretation guide
    cat("Interpretation:\n")
    cat("  mean:      Average value over time (high for forests, low for bareland)\n")
    cat("  std:       Temporal stability (low = stable like forest, high = variable like ladang)\n")
    cat("  min:       Lowest value (shows bare phases for ladang)\n")
    cat("  max:       Highest value (peak vegetation)\n")
    cat("  amplitude: Half the range (temporal variation)\n\n")

    # Highlight key discriminators
    cat("Key patterns to look for:\n")
    cat("  - Forest: high mean, low std (stable high vegetation)\n")
    cat("  - Ladang: moderate mean, high std (cycles between bare and vegetated)\n")
    cat("  - Paddy: moderate mean, high std (flooding cycles)\n")
    cat("  - Bareland: low mean, low std (stable low)\n")
    cat("  - Water: depends on index (NDWI high for water)\n\n")
}

# ==============================================================================
# Example usage and recommendations
# ==============================================================================

cat("========================================\n")
cat("Temporal Features for Land Cover Classification\n")
cat("========================================\n\n")

cat("WHY USE TEMPORAL STATISTICS?\n\n")

cat("1. Raw time series (sits default):\n")
cat("   - Uses all individual date values: [NDVI_2023-01-01, NDVI_2023-05-01, ...]\n")
cat("   - Good: Captures exact temporal patterns\n")
cat("   - Challenge: Many features (19 dates × 24 bands = 456 features)\n")
cat("   - Challenge: Sensitive to missing dates\n\n")

cat("2. Temporal statistics (this script):\n")
cat("   - Creates summary features: NDVI_mean, NDVI_std, NDVI_min, NDVI_max, etc.\n")
cat("   - Good: Robust to irregular sampling\n")
cat("   - Good: Easier to interpret\n")
cat("   - Good: Captures temporal characteristics (stability, amplitude)\n")
cat("   - Example: 'Natural forest has high stable NDVI' = NDVI_mean=0.85, NDVI_std=0.05\n\n")

cat("3. Combined approach (RECOMMENDED):\n")
cat("   - Use BOTH raw time series AND statistics\n")
cat("   - ML algorithm selects most informative features\n")
cat("   - Best of both worlds\n\n")

cat("========================================\n")
cat("USAGE EXAMPLES\n")
cat("========================================\n\n")

cat("# Load the script\n")
cat("source('scripts/temporal_features.R')\n\n")

cat("# After extracting time series (in classify_planetscope.R):\n")
cat("training_data <- sits_get_data(cube = planet_cube, samples = training_samples_sf)\n\n")

cat("# Add temporal features (keep time series too)\n")
cat("training_data <- prepare_temporal_features(training_data, use_time_series = TRUE)\n\n")

cat("# Or use ONLY statistics (faster, fewer features)\n")
cat("training_data <- prepare_temporal_features(training_data, use_time_series = FALSE)\n\n")

cat("# Compare classes\n")
cat("compare_temporal_features(training_data, band = 'NDVI')\n")
cat("compare_temporal_features(training_data, band = 'NDRE')\n")
cat("compare_temporal_features(training_data, band = 'NDWI')\n\n")

cat("========================================\n")
cat("RECOMMENDED STATISTICS FOR YOUR CLASSES\n")
cat("========================================\n\n")

cat("Class                | Key Temporal Features\n")
cat("---------------------|-----------------------------------------------\n")
cat("Natural Forest       | NDVI_mean (high), NDVI_std (low), NDRE_mean (high)\n")
cat("Production Forest    | NDVI_mean (high), NDVI_std (low-med), NDRE_mean (lower)\n")
cat("Agroforest           | NDVI_mean (medium), NDVI_std (medium)\n")
cat("Paddy                | NDVI_amplitude (high), NDWI_max (high), NDVI_std (high)\n")
cat("Ladang               | NDVI_amplitude (high), BSI_max (high), NDVI_std (high)\n")
cat("Grassland            | NDVI_mean (medium), GNDVI_mean (characteristic)\n")
cat("Sparse Vegetation    | NDVI_mean (low-med), SAVI_mean (better than NDVI)\n")
cat("Bareland             | NDVI_mean (very low), BSI_mean (high), NDVI_std (low)\n")
cat("Settlement           | NDVI_mean (low), UI_mean (positive), NDVI_std (very low)\n")
cat("Water                | NDWI_mean (very high), NDVI_mean (very low), NDVI_std (low)\n\n")

cat("========================================\n\n")
