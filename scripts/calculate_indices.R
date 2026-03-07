#!/usr/bin/env Rscript
# Calculate spectral indices for PlanetScope 8-band data
# This script defines index formulas optimized for land cover classification

# ==============================================================================
# PlanetScope 8-band structure:
# B1: Coastal Blue (431-452 nm)
# B2: Blue (465-515 nm)
# B3: Green I (513-549 nm)
# B4: Green (547-583 nm)
# B5: Yellow (600-620 nm)
# B6: Red (650-680 nm)
# B7: Red Edge (697-713 nm)
# B8: NIR (845-885 nm)
# ==============================================================================

#' Add spectral indices to sits cube
#'
#' This function calculates multiple spectral indices optimized for
#' distinguishing between different land cover types including:
#' paddy, water, settlement, bareland, forests, agroforest, ladang,
#' sparse vegetation, and grassland.
#'
#' @param cube A sits cube
#' @param indices Character vector of indices to calculate.
#'                Options: "all", "vegetation", "water", "soil", "urban"
#'                Default: "all"
#' @return A sits cube with additional index bands
#' @export
add_indices <- function(cube, indices = "all") {

    # Define which indices to calculate
    if ("all" %in% indices) {
        indices <- c("vegetation", "water", "soil", "urban")
    }

    index_list <- list()

    # ==============================================================================
    # Vegetation Indices
    # ==============================================================================
    if ("vegetation" %in% indices) {

        # NDVI - Normalized Difference Vegetation Index
        # Best for: Overall vegetation vigor, all vegetation classes
        # Range: -1 to 1 (higher = more vegetation)
        index_list$NDVI <- function(B8, B6) {
            (B8 - B6) / (B8 + B6)
        }

        # EVI - Enhanced Vegetation Index
        # Best for: Dense vegetation (forests), reduces saturation
        # Range: -1 to 1
        index_list$EVI <- function(B8, B6, B2) {
            2.5 * ((B8 - B6) / (B8 + 6 * B6 - 7.5 * B2 + 1))
        }

        # SAVI - Soil Adjusted Vegetation Index
        # Best for: Sparse vegetation, ladang, grassland
        # Reduces soil background influence
        index_list$SAVI <- function(B8, B6) {
            L <- 0.5  # soil brightness correction factor
            ((B8 - B6) / (B8 + B6 + L)) * (1 + L)
        }

        # NDRE - Normalized Difference Red Edge
        # Best for: Forest types, chlorophyll content
        # Sensitive to forest health and type
        index_list$NDRE <- function(B8, B7) {
            (B8 - B7) / (B8 + B7)
        }

        # GNDVI - Green NDVI
        # Best for: Chlorophyll content, grassland vs forest
        index_list$GNDVI <- function(B8, B4) {
            (B8 - B4) / (B8 + B4)
        }

        # GCI - Green Chlorophyll Index
        # Best for: Vegetation health, photosynthetic activity
        index_list$GCI <- function(B8, B4) {
            (B8 / B4) - 1
        }

        # CIre - Chlorophyll Index Red Edge
        # Best for: Discriminating forest types
        index_list$CIre <- function(B8, B7) {
            (B8 / B7) - 1
        }
    }

    # ==============================================================================
    # Water Indices
    # ==============================================================================
    if ("water" %in% indices) {

        # NDWI - Normalized Difference Water Index
        # Best for: Water bodies, paddy fields (flooded)
        # High values indicate water
        index_list$NDWI <- function(B4, B8) {
            (B4 - B8) / (B4 + B8)
        }

        # MNDWI - Modified NDWI (using Green I instead)
        # Best for: Water detection, separating from built-up
        index_list$MNDWI <- function(B3, B8) {
            (B3 - B8) / (B3 + B8)
        }

        # LSWI - Land Surface Water Index
        # Best for: Soil moisture, paddy detection
        # Uses NIR and Red Edge as proxy
        index_list$LSWI <- function(B8, B7) {
            (B8 - B7) / (B8 + B7)
        }
    }

    # ==============================================================================
    # Soil/Bareland Indices
    # ==============================================================================
    if ("soil" %in% indices) {

        # BSI - Bare Soil Index (adapted for PlanetScope)
        # Best for: Bareland detection
        index_list$BSI <- function(B6, B4, B8, B2) {
            ((B6 + B4) - (B8 + B2)) / ((B6 + B4) + (B8 + B2))
        }

        # BI - Brightness Index
        # Best for: Distinguishing bare soil from vegetation
        index_list$BI <- function(B6, B4) {
            sqrt((B6^2 + B4^2) / 2)
        }

        # NDTI - Normalized Difference Tillage Index
        # Best for: Agricultural bare soil (ladang bare phase)
        index_list$NDTI <- function(B6, B4) {
            (B6 - B4) / (B6 + B4)
        }
    }

    # ==============================================================================
    # Urban/Built-up Indices
    # ==============================================================================
    if ("urban" %in% indices) {

        # UI - Urban Index (adapted - no SWIR in PlanetScope)
        # Best for: Settlement detection
        # Uses Red-NIR relationship
        index_list$UI <- function(B6, B8) {
            (B6 - B8) / (B6 + B8)
        }

        # BAEI - Built-up Area Extraction Index (adapted)
        # Best for: Built-up vs natural features
        index_list$BAEI <- function(B6, B4, B8) {
            (B6 + 0.3) / (B4 + B8)
        }

        # VIBI - Visible Built-up Index
        # Best for: Urban areas using visible bands
        index_list$VIBI <- function(B6, B2) {
            (B6 - B2) / (B6 + B2)
        }
    }

    # ==============================================================================
    # Apply indices to cube
    # ==============================================================================

    cat("Adding spectral indices to cube...\n")
    cat("  Indices to calculate:", length(index_list), "\n")
    cat("  ", paste(names(index_list), collapse = ", "), "\n\n")

    # Add each index as a new band
    for (index_name in names(index_list)) {
        cat("  Calculating", index_name, "...\n")

        cube <- sits_apply(
            data = cube,
            output_band = index_name,
            NDVI = index_list$NDVI,
            EVI = index_list$EVI,
            SAVI = index_list$SAVI,
            NDRE = index_list$NDRE,
            GNDVI = index_list$GNDVI,
            GCI = index_list$GCI,
            CIre = index_list$CIre,
            NDWI = index_list$NDWI,
            MNDWI = index_list$MNDWI,
            LSWI = index_list$LSWI,
            BSI = index_list$BSI,
            BI = index_list$BI,
            NDTI = index_list$NDTI,
            UI = index_list$UI,
            BAEI = index_list$BAEI,
            VIBI = index_list$VIBI,
            memsize = 8,
            multicores = 4
        )
    }

    cat("\n  Done! Added", length(index_list), "indices\n\n")

    return(cube)
}

# ==============================================================================
# Recommended index combinations for specific classes
# ==============================================================================

#' Get recommended indices for specific land cover classes
#'
#' @param classes Character vector of class names
#' @return List of recommended indices for each class
#' @export
get_recommended_indices <- function(classes = "all") {

    recommendations <- list(
        paddy = c("NDVI", "NDWI", "LSWI", "SAVI", "EVI"),
        water = c("NDWI", "MNDWI", "NDVI"),
        settlement = c("UI", "BAEI", "VIBI", "NDVI"),
        bareland = c("BSI", "NDVI", "NDTI", "BI"),
        natural_forest = c("NDVI", "EVI", "NDRE", "CIre", "GNDVI"),
        production_forest = c("NDVI", "EVI", "NDRE", "GCI", "SAVI"),
        agroforest = c("NDVI", "NDRE", "SAVI", "GCI"),
        ladang = c("NDVI", "SAVI", "NDTI", "EVI", "BSI"),
        sparse_vegetation = c("SAVI", "NDVI", "GNDVI", "BSI"),
        grassland = c("NDVI", "GNDVI", "SAVI", "GCI")
    )

    if ("all" %in% classes) {
        return(recommendations)
    } else {
        return(recommendations[classes])
    }
}

# ==============================================================================
# Print index information
# ==============================================================================

cat("========================================\n")
cat("PlanetScope Spectral Indices Library\n")
cat("========================================\n\n")

cat("Available index groups:\n")
cat("  - vegetation: NDVI, EVI, SAVI, NDRE, GNDVI, GCI, CIre\n")
cat("  - water: NDWI, MNDWI, LSWI\n")
cat("  - soil: BSI, BI, NDTI\n")
cat("  - urban: UI, BAEI, VIBI\n\n")

cat("Usage:\n")
cat("  source('scripts/calculate_indices.R')\n\n")
cat("  # Add all indices\n")
cat("  cube_with_indices <- add_indices(cube, indices = 'all')\n\n")
cat("  # Add only vegetation indices\n")
cat("  cube_with_indices <- add_indices(cube, indices = 'vegetation')\n\n")
cat("  # Add specific groups\n")
cat("  cube_with_indices <- add_indices(cube, indices = c('vegetation', 'water'))\n\n")

cat("Index recommendations for your classes:\n")
recommendations <- get_recommended_indices("all")
for (class_name in names(recommendations)) {
    cat("  ", class_name, ": ", paste(recommendations[[class_name]], collapse = ", "), "\n", sep = "")
}
cat("\n")
