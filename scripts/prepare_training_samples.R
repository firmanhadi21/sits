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
    # CSV should have columns: longitude, latitude, label
    # Example:
    #   longitude,latitude,label
    #   -47.123,10.456,forest
    #   -47.124,10.457,water
    #   -47.125,10.458,cropland

    cat("Creating samples from CSV...\n")

    samples_df <- read.csv(csv_file)

    # Convert to sf object
    samples_sf <- sf::st_as_sf(
        samples_df,
        coords = c("longitude", "latitude"),
        crs = 4326  # WGS84
    )

    # Save as GeoPackage
    sf::st_write(samples_sf, output_file, delete_dsn = TRUE)

    cat("  Created", nrow(samples_sf), "samples\n")
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
            cat("    OK: Samples overlap with cube extent\n")
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

    # Generate random points within each polygon
    all_points <- list()

    for (i in 1:nrow(polygons)) {
        polygon <- polygons[i, ]

        # Generate random points
        points <- sf::st_sample(polygon, size = points_per_polygon)

        # Convert to sf and add attributes
        points_sf <- sf::st_sf(
            label = polygon$label,
            geometry = points
        )

        all_points[[i]] <- points_sf
    }

    # Combine all points
    all_points_sf <- do.call(rbind, all_points)

    # Save
    sf::st_write(all_points_sf, output_file, delete_dsn = TRUE)

    cat("  Created", nrow(all_points_sf), "points from", nrow(polygons), "polygons\n")
    cat("  Saved to:", output_file, "\n\n")

    return(all_points_sf)
}

# ==============================================================================
# Example usage
# ==============================================================================

cat("This script provides functions to prepare training samples.\n\n")

cat("Available functions:\n\n")

cat("1. create_samples_from_csv(csv_file, output_file)\n")
cat("   Create samples from CSV with longitude, latitude, label columns\n\n")

cat("2. create_samples_from_reference(reference_raster, n_samples_per_class, output_file)\n")
cat("   Extract random samples from an existing classification\n\n")

cat("3. validate_training_samples(samples_file, cube = NULL)\n")
cat("   Validate existing training samples\n\n")

cat("4. convert_polygons_to_points(polygon_file, points_per_polygon, output_file)\n")
cat("   Convert polygon samples to point samples\n\n")

cat("Example workflow:\n\n")
cat("  # Option A: From CSV\n")
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
