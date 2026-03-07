#!/usr/bin/env Rscript
# Create spectral index composites for each date
# Generates NDVI, NDWI, NDRE, EVI, SAVI, BSI, and other indices

suppressPackageStartupMessages({
    library(terra)
})

cat("========================================\n")
cat("Creating Spectral Index Composites\n")
cat("========================================\n\n")

# Configuration
INPUT_DIR <- "data/planetscope_mosaicked"
OUTPUT_DIR <- "data/planetscope_indices"

# Indices to calculate
INDICES <- c(
    "NDVI",   # Normalized Difference Vegetation Index
    "NDWI",   # Normalized Difference Water Index
    "NDRE",   # Normalized Difference Red Edge
    "EVI",    # Enhanced Vegetation Index
    "SAVI",   # Soil Adjusted Vegetation Index
    "GNDVI",  # Green NDVI
    "BSI",    # Bare Soil Index
    "NDTI"    # Normalized Difference Tillage Index
)

# Create output directories
for (index in INDICES) {
    index_dir <- file.path(OUTPUT_DIR, index)
    if (!dir.exists(index_dir)) {
        dir.create(index_dir, recursive = TRUE)
    }
}

cat("Output directory:", OUTPUT_DIR, "\n")
cat("Indices to calculate:", paste(INDICES, collapse = ", "), "\n\n")

# Get all dates
b1_files <- list.files(INPUT_DIR, pattern = "_B1\\.tif$", full.names = FALSE)
dates <- sub("^([0-9]{8})_.*", "\\1", b1_files)
unique_dates <- unique(dates)
unique_dates <- sort(unique_dates)

cat("Found", length(unique_dates), "dates to process\n")
cat("Date range:", unique_dates[1], "to", unique_dates[length(unique_dates)], "\n\n")

# Index calculation functions
calculate_ndvi <- function(nir, red) {
    # NDVI = (NIR - Red) / (NIR + Red)
    (nir - red) / (nir + red)
}

calculate_ndwi <- function(green, nir) {
    # NDWI = (Green - NIR) / (Green + NIR)
    (green - nir) / (green + nir)
}

calculate_ndre <- function(nir, rededge) {
    # NDRE = (NIR - RedEdge) / (NIR + RedEdge)
    (nir - rededge) / (nir + rededge)
}

calculate_evi <- function(nir, red, blue) {
    # EVI = 2.5 * ((NIR - Red) / (NIR + 6*Red - 7.5*Blue + 1))
    2.5 * ((nir - red) / (nir + 6 * red - 7.5 * blue + 1))
}

calculate_savi <- function(nir, red, L = 0.5) {
    # SAVI = ((NIR - Red) / (NIR + Red + L)) * (1 + L)
    ((nir - red) / (nir + red + L)) * (1 + L)
}

calculate_gndvi <- function(nir, green) {
    # GNDVI = (NIR - Green) / (NIR + Green)
    (nir - green) / (nir + green)
}

calculate_bsi <- function(red, green, nir, blue) {
    # BSI = ((Red + Green) - (NIR + Blue)) / ((Red + Green) + (NIR + Blue))
    ((red + green) - (nir + blue)) / ((red + green) + (nir + blue))
}

calculate_ndti <- function(red, green) {
    # NDTI = (Red - Green) / (Red + Green)
    (red - green) / (red + green)
}

# Process each date
success_matrix <- matrix(0, nrow = length(unique_dates), ncol = length(INDICES))
rownames(success_matrix) <- unique_dates
colnames(success_matrix) <- INDICES

for (i in seq_along(unique_dates)) {
    date <- unique_dates[i]
    cat(sprintf("[%2d/%2d] Processing %s ...\n", i, length(unique_dates), date))

    # Load all required bands
    tryCatch({
        # Find band files
        b1_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_.*_B1\\.tif$"), full.names = TRUE)[1]
        b2_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_.*_B2\\.tif$"), full.names = TRUE)[1]
        b3_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_.*_B3\\.tif$"), full.names = TRUE)[1]
        b4_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_.*_B4\\.tif$"), full.names = TRUE)[1]
        b5_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_.*_B5\\.tif$"), full.names = TRUE)[1]
        b6_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_.*_B6\\.tif$"), full.names = TRUE)[1]
        b7_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_.*_B7\\.tif$"), full.names = TRUE)[1]
        b8_file <- list.files(INPUT_DIR, pattern = paste0("^", date, "_.*_B8\\.tif$"), full.names = TRUE)[1]

        # Load bands as rasters
        b1 <- rast(b1_file)  # Coastal Blue
        b2 <- rast(b2_file)  # Blue
        b3 <- rast(b3_file)  # Green I
        b4 <- rast(b4_file)  # Green
        b5 <- rast(b5_file)  # Yellow
        b6 <- rast(b6_file)  # Red
        b7 <- rast(b7_file)  # Red Edge
        b8 <- rast(b8_file)  # NIR

        # Calculate indices
        indices_list <- list()

        # NDVI
        if ("NDVI" %in% INDICES) {
            ndvi <- calculate_ndvi(b8, b6)
            output_file <- file.path(OUTPUT_DIR, "NDVI", paste0(date, "_NDVI.tif"))
            writeRaster(ndvi, output_file, overwrite = TRUE, datatype = "FLT4S",
                       gdal = c("COMPRESS=LZW"))
            success_matrix[date, "NDVI"] <- 1
        }

        # NDWI
        if ("NDWI" %in% INDICES) {
            ndwi <- calculate_ndwi(b4, b8)
            output_file <- file.path(OUTPUT_DIR, "NDWI", paste0(date, "_NDWI.tif"))
            writeRaster(ndwi, output_file, overwrite = TRUE, datatype = "FLT4S",
                       gdal = c("COMPRESS=LZW"))
            success_matrix[date, "NDWI"] <- 1
        }

        # NDRE
        if ("NDRE" %in% INDICES) {
            ndre <- calculate_ndre(b8, b7)
            output_file <- file.path(OUTPUT_DIR, "NDRE", paste0(date, "_NDRE.tif"))
            writeRaster(ndre, output_file, overwrite = TRUE, datatype = "FLT4S",
                       gdal = c("COMPRESS=LZW"))
            success_matrix[date, "NDRE"] <- 1
        }

        # EVI
        if ("EVI" %in% INDICES) {
            evi <- calculate_evi(b8, b6, b2)
            output_file <- file.path(OUTPUT_DIR, "EVI", paste0(date, "_EVI.tif"))
            writeRaster(evi, output_file, overwrite = TRUE, datatype = "FLT4S",
                       gdal = c("COMPRESS=LZW"))
            success_matrix[date, "EVI"] <- 1
        }

        # SAVI
        if ("SAVI" %in% INDICES) {
            savi <- calculate_savi(b8, b6)
            output_file <- file.path(OUTPUT_DIR, "SAVI", paste0(date, "_SAVI.tif"))
            writeRaster(savi, output_file, overwrite = TRUE, datatype = "FLT4S",
                       gdal = c("COMPRESS=LZW"))
            success_matrix[date, "SAVI"] <- 1
        }

        # GNDVI
        if ("GNDVI" %in% INDICES) {
            gndvi <- calculate_gndvi(b8, b4)
            output_file <- file.path(OUTPUT_DIR, "GNDVI", paste0(date, "_GNDVI.tif"))
            writeRaster(gndvi, output_file, overwrite = TRUE, datatype = "FLT4S",
                       gdal = c("COMPRESS=LZW"))
            success_matrix[date, "GNDVI"] <- 1
        }

        # BSI
        if ("BSI" %in% INDICES) {
            bsi <- calculate_bsi(b6, b4, b8, b2)
            output_file <- file.path(OUTPUT_DIR, "BSI", paste0(date, "_BSI.tif"))
            writeRaster(bsi, output_file, overwrite = TRUE, datatype = "FLT4S",
                       gdal = c("COMPRESS=LZW"))
            success_matrix[date, "BSI"] <- 1
        }

        # NDTI
        if ("NDTI" %in% INDICES) {
            ndti <- calculate_ndti(b6, b4)
            output_file <- file.path(OUTPUT_DIR, "NDTI", paste0(date, "_NDTI.tif"))
            writeRaster(ndti, output_file, overwrite = TRUE, datatype = "FLT4S",
                       gdal = c("COMPRESS=LZW"))
            success_matrix[date, "NDTI"] <- 1
        }

        # Count successful indices
        n_success <- sum(success_matrix[date, ])
        cat(sprintf("        Created %d/%d indices\n", n_success, length(INDICES)))

    }, error = function(e) {
        cat("        ERROR:", conditionMessage(e), "\n")
    })
}

cat("\n========================================\n")
cat("Index Composite Creation Complete!\n")
cat("========================================\n\n")

# Summary statistics
total_success <- sum(success_matrix)
total_possible <- length(unique_dates) * length(INDICES)

cat("Results:\n")
cat("  Total indices created:", total_success, "/", total_possible, "\n")
cat("  Success rate:", sprintf("%.1f%%", 100 * total_success / total_possible), "\n\n")

# Per-index summary
cat("Indices created per date:\n")
for (index in INDICES) {
    n_created <- sum(success_matrix[, index])
    cat(sprintf("  %-8s: %2d/%2d dates\n", index, n_created, length(unique_dates)))
}
cat("\n")

cat("Output structure:\n")
cat("  data/planetscope_indices/\n")
for (index in INDICES) {
    index_dir <- file.path(OUTPUT_DIR, index)
    n_files <- length(list.files(index_dir, pattern = "\\.tif$"))
    if (n_files > 0) {
        cat(sprintf("    ├── %-8s/ (%d files)\n", index, n_files))
    }
}
cat("\n")

cat("Index descriptions:\n")
cat("  NDVI  : Vegetation vigor (higher = more vegetation)\n")
cat("  NDWI  : Water content (higher = more water)\n")
cat("  NDRE  : Red edge (forest health, chlorophyll)\n")
cat("  EVI   : Enhanced vegetation (reduces saturation in dense vegetation)\n")
cat("  SAVI  : Soil-adjusted vegetation (good for sparse vegetation)\n")
cat("  GNDVI : Green NDVI (sensitive to chlorophyll)\n")
cat("  BSI   : Bare soil (higher = more bare soil)\n")
cat("  NDTI  : Tillage/bare soil (agricultural areas)\n\n")

cat("Typical value ranges:\n")
cat("  NDVI, NDWI, NDRE, GNDVI, NDTI: -1 to 1\n")
cat("  EVI: -1 to 1 (typically 0 to 0.8)\n")
cat("  SAVI: -1 to 1.5\n")
cat("  BSI: -1 to 1\n\n")

cat("Next steps:\n")
cat("1. Visualize in QGIS:\n")
cat("   - Load index files from data/planetscope_indices/<INDEX>/\n")
cat("   - Apply color ramp (e.g., RdYlGn for NDVI)\n")
cat("   - Set min/max values based on ranges above\n\n")

cat("2. Temporal analysis:\n")
cat("   - Compare same index across different dates\n")
cat("   - Identify seasonal patterns\n")
cat("   - Detect land cover changes\n\n")

cat("3. Multi-index comparison:\n")
cat("   - Combine NDVI + NDWI to separate vegetation from water\n")
cat("   - Use NDRE to distinguish forest types\n")
cat("   - Use BSI to identify bare/cultivated land\n\n")
