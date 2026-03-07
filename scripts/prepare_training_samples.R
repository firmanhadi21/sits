#!/usr/bin/env Rscript
# Prepare training samples for PlanetScope classification
# This script helps create and validate training samples

suppressPackageStartupMessages({
    library(sits)
    library(sf)
})

cat("========================================\n")
cat("Training Sample Preparation\n")
cat("========================================\n\n")

# ==============================================================================
# Option 1: Create samples from CSV with coordinates
# ==============================================================================

create_samples_from_csv <- function(csv_file, output_file) {
    # CSV should have columns: longitude, latitude, label, start_date, end_date
    # Example:
    #   longitude,latitude,label,start_date,end_date
    #   -47.123,10.456,forest,2023-01-01,2025-12-31
    #   -47.124,10.457,water,2024-01-01,2024-12-31
    #   -47.125,10.458,cropland,2024-07-01,2024-09-30
    #
    # Or minimal format with just date: longitude, latitude, label, date
    #   longitude,latitude,label,date
    #   -47.123,10.456,forest,2024-07-14

    cat("Creating samples from CSV...\n")

    samples_df <- read.csv(csv_file, stringsAsFactors = FALSE)

    # Check for date columns
    has_dates <- "start_date" %in% names(samples_df) || "date" %in% names(samples_df)

    if (!has_dates) {
        cat("  WARNING: No date information found in CSV!\n")
        cat("  It's recommended to include start_date and end_date columns.\n")
        cat("  Without dates, the entire time series will be used for each sample.\n\n")
    } else {
        # Handle single 'date' column
        if ("date" %in% names(samples_df) && !"start_date" %in% names(samples_df)) {
            samples_df$start_date <- samples_df$date
            samples_df$end_date <- samples_df$date
        }

        # Convert date columns to Date type
        if ("start_date" %in% names(samples_df)) {
            samples_df$start_date <- as.Date(samples_df$start_date)
        }
        if ("end_date" %in% names(samples_df)) {
            samples_df$end_date <- as.Date(samples_df$end_date)
        }
    }

    # Convert to sf object
    coord_cols <- c("longitude", "latitude")
    if (!all(coord_cols %in% names(samples_df))) {
        stop("CSV must have 'longitude' and 'latitude' columns!")
    }

    samples_sf <- sf::st_as_sf(
        samples_df,
        coords = coord_cols,
        crs = 4326  # WGS84
    )

    # Save as GeoPackage
    sf::st_write(samples_sf, output_file, delete_dsn = TRUE)

    cat("  Created", nrow(samples_sf), "samples\n")
    if (has_dates) {
        cat("  Date range:", min(samples_df$start_date, na.rm = TRUE), "to",
            max(samples_df$end_date, na.rm = TRUE), "\n")
    }
    cat("  Saved to:", output_file, "\n\n")

    return(samples_sf)
}

# ==============================================================================
# Option 2: Create random samples from existing classification
# ==============================================================================

create_samples_from_reference <- function(reference_raster,
                                          n_samples_per_class = 50,
                                          output_file) {
    # If you have a reference classification map, extract random samples

    cat("Creating samples from reference raster...\n")

    # Load reference raster
    ref <- terra::rast(reference_raster)

    # Get unique classes
    classes <- unique(terra::values(ref))
    classes <- classes[!is.na(classes)]

    # Sample points for each class
    all_samples <- list()

    for (class_val in classes) {
        # Create mask for this class
        class_mask <- ref == class_val

        # Generate random points
        points <- terra::spatSample(
            class_mask,
            size = n_samples_per_class,
            method = "random",
            na.rm = TRUE,
            as.points = TRUE
        )

        # Add label
        points$label <- paste0("class_", class_val)

        all_samples[[length(all_samples) + 1]] <- points
    }

    # Combine all samples
    samples_vect <- do.call(rbind, all_samples)

    # Convert to sf
    samples_sf <- sf::st_as_sf(samples_vect)

    # Save
    sf::st_write(samples_sf, output_file, delete_dsn = TRUE)

    cat("  Created", nrow(samples_sf), "samples\n")
    cat("  Classes:", paste(unique(samples_sf$label), collapse = ", "), "\n")
    cat("  Saved to:", output_file, "\n\n")

    return(samples_sf)
}

# ==============================================================================
# Option 3: Validate existing training samples
# ==============================================================================

validate_training_samples <- function(samples_file, cube = NULL) {
    cat("Validating training samples...\n")
    cat("  File:", samples_file, "\n\n")

    # Read samples
    samples <- sf::st_read(samples_file, quiet = TRUE)

    # Check for required columns
    if (!"label" %in% names(samples)) {
        cat("  ERROR: Samples must have a 'label' column!\n")
        return(FALSE)
    }

    # Check for date columns
    has_dates <- "start_date" %in% names(samples) && "end_date" %in% names(samples)
    if (!has_dates) {
        cat("  WARNING: No start_date/end_date columns found!\n")
        cat("  It's recommended to include temporal information for each sample.\n")
        cat("  This ensures labels are only applied to the correct time period.\n\n")
    } else {
        cat("  Date information: YES\n")
        samples$start_date <- as.Date(samples$start_date)
        samples$end_date <- as.Date(samples$end_date)
        cat("  Date range:", min(samples$start_date, na.rm = TRUE), "to",
            max(samples$end_date, na.rm = TRUE), "\n")
    }

    # Check geometry type
    geom_type <- sf::st_geometry_type(samples, by_geometry = FALSE)
    cat("  Geometry type:", as.character(geom_type), "\n")

    # Check CRS
    crs <- sf::st_crs(samples)
    cat("  CRS:", crs$input, "\n")

    # Check sample distribution
    cat("\n  Sample distribution:\n")
    label_counts <- table(samples$label)
    for (label in names(label_counts)) {
        cat("    -", label, ":", label_counts[label], "samples\n")
    }

    # Check spatial extent
    bbox <- sf::st_bbox(samples)
    cat("\n  Spatial extent:\n")
    cat("    xmin:", bbox["xmin"], "\n")
    cat("    xmax:", bbox["xmax"], "\n")
    cat("    ymin:", bbox["ymin"], "\n")
    cat("    ymax:", bbox["ymax"], "\n")

    # If cube is provided, check overlap
    if (!is.null(cube)) {
        cat("\n  Checking overlap with cube...\n")

        # Get cube extent
        cube_bbox <- sits_bbox(cube)

        # Check if samples fall within cube extent
        samples_in_cube <- samples[
            bbox["xmin"] >= cube_bbox["xmin"] &
            bbox["xmax"] <= cube_bbox["xmax"] &
            bbox["ymin"] >= cube_bbox["ymin"] &
            bbox["ymax"] <= cube_bbox["ymax"],
        ]

        if (nrow(samples_in_cube) == 0) {
            cat("    WARNING: No samples overlap with cube extent!\n")
            cat("    Check that CRS and coordinates are correct.\n")
        } else {
            cat("    OK:", nrow(samples_in_cube), "samples overlap with cube extent\n")
        }

        # Check temporal overlap
        if (has_dates) {
            cube_timeline <- sits_timeline(cube)
            cube_start <- min(as.Date(cube_timeline))
            cube_end <- max(as.Date(cube_timeline))

            sample_start <- min(samples$start_date, na.rm = TRUE)
            sample_end <- max(samples$end_date, na.rm = TRUE)

            cat("\n  Temporal overlap check:\n")
            cat("    Cube timeline:", cube_start, "to", cube_end, "\n")
            cat("    Sample dates:", sample_start, "to", sample_end, "\n")

            if (sample_end < cube_start || sample_start > cube_end) {
                cat("    WARNING: No temporal overlap between samples and cube!\n")
            } else {
                cat("    OK: Temporal overlap exists\n")
            }
        }
    }

    cat("\n  Validation complete!\n\n")
    return(TRUE)
}

# ==============================================================================
# Option 4: Convert polygon samples to points
# ==============================================================================

convert_polygons_to_points <- function(polygon_file,
                                      points_per_polygon = 10,
                                      output_file) {
    cat("Converting polygons to points...\n")

    # Read polygons
    polygons <- sf::st_read(polygon_file, quiet = TRUE)

    # Check if polygons have date information
    has_dates <- "start_date" %in% names(polygons) && "end_date" %in% names(polygons)

    # Generate random points within each polygon
    all_points <- list()

    for (i in 1:nrow(polygons)) {
        polygon <- polygons[i, ]

        # Generate random points
        points <- sf::st_sample(polygon, size = points_per_polygon)

        # Convert to sf and add attributes
        if (has_dates) {
            points_sf <- sf::st_sf(
                label = polygon$label,
                start_date = polygon$start_date,
                end_date = polygon$end_date,
                geometry = points
            )
        } else {
            points_sf <- sf::st_sf(
                label = polygon$label,
                geometry = points
            )
        }

        all_points[[i]] <- points_sf
    }

    # Combine all points
    all_points_sf <- do.call(rbind, all_points)

    # Save
    sf::st_write(all_points_sf, output_file, delete_dsn = TRUE)

    cat("  Created", nrow(all_points_sf), "points from", nrow(polygons), "polygons\n")
    if (has_dates) {
        cat("  Date information preserved\n")
    }
    cat("  Saved to:", output_file, "\n\n")

    return(all_points_sf)
}

# ==============================================================================
# Example usage
# ==============================================================================

cat("This script provides functions to prepare training samples.\n\n")

cat("Available functions:\n\n")

cat("1. create_samples_from_csv(csv_file, output_file)\n")
cat("   Create samples from CSV with longitude, latitude, label, start_date, end_date columns\n\n")

cat("2. create_samples_from_reference(reference_raster, n_samples_per_class, output_file)\n")
cat("   Extract random samples from an existing classification\n\n")

cat("3. validate_training_samples(samples_file, cube = NULL)\n")
cat("   Validate existing training samples\n\n")

cat("4. convert_polygons_to_points(polygon_file, points_per_polygon, output_file)\n")
cat("   Convert polygon samples to point samples\n\n")

cat("Example CSV format (RECOMMENDED):\n")
cat("  longitude,latitude,label,start_date,end_date\n")
cat("  -47.123,10.456,forest,2023-01-01,2025-12-31\n")
cat("  -47.124,10.457,water,2024-01-01,2024-12-31\n")
cat("  -47.125,10.458,cropland,2024-07-01,2024-09-30\n\n")

cat("Or minimal format with single date:\n")
cat("  longitude,latitude,label,date\n")
cat("  -47.123,10.456,forest,2024-07-14\n\n")

cat("Example workflow:\n\n")
cat("  # Option A: From CSV with dates\n")
cat("  samples <- create_samples_from_csv(\n")
cat("      csv_file = 'data/training_points.csv',\n")
cat("      output_file = 'data/training_samples.gpkg'\n")
cat("  )\n\n")

cat("  # Option B: From polygon shapefile\n")
cat("  samples <- convert_polygons_to_points(\n")
cat("      polygon_file = 'data/training_polygons.shp',\n")
cat("      points_per_polygon = 20,\n")
cat("      output_file = 'data/training_samples.gpkg'\n")
cat("  )\n\n")

cat("  # Validate samples\n")
cat("  validate_training_samples(\n")
cat("      samples_file = 'data/training_samples.gpkg'\n")
cat("  )\n\n")

cat("========================================\n\n")
