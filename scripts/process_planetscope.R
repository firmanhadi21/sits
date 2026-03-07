#!/usr/bin/env Rscript
# Process PlanetScope zip files for use with sits
# This script:
# 1. Extracts zip files
# 2. Splits 8-band tifs into separate single-band files
# 3. Renames them to B1-B8 format

suppressPackageStartupMessages({
    library(argparse)
})

parser <- ArgumentParser(description = "Process PlanetScope zip files for sits")
parser$add_argument("input_dir", help = "Directory containing PlanetScope zip files")
parser$add_argument("output_dir", help = "Output directory for processed files")

args <- parser$parse_args()

input_dir <- normalizePath(args$input_dir)
output_dir <- normalizePath(args$output_dir)

cat("Processing PlanetScope data\n")
cat("Input:", input_dir, "\n")
cat("Output:", output_dir, "\n\n")

if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
}

zip_files <- list.files(input_dir, pattern = "\\.zip$", full.names = TRUE)

if (length(zip_files) == 0) {
    stop("No zip files found in ", input_dir)
}

cat("Found", length(zip_files), "zip files\n\n")

for (zip_file in zip_files) {
    cat("Processing:", basename(zip_file), "\n")
    
    temp_dir <- tempfile(pattern = "planet_")
    dir.create(temp_dir)
    on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
    
    cat("  Extracting...\n")
    unzip(zip_file, exdir = temp_dir, overwrite = TRUE)
    
    tif_files <- list.files(temp_dir, pattern = "_SR_8b.*\\.tif$", 
                            full.names = TRUE, recursive = TRUE)
    
    if (length(tif_files) == 0) {
        cat("  WARNING: No 8-band SR files found, skipping\n\n")
        next
    }
    
    cat("  Processing", length(tif_files), "files...\n")
    
    for (tif_file in tif_files) {
        base_name <- basename(tif_file)

        # Remove .tif extension to build output filenames
        base_name_no_ext <- sub("\\.tif$", "", base_name)

        bands <- c("B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8")

        for (i in seq_along(bands)) {
            band_code <- bands[i]

            # Create output filename: original_name_B1.tif, original_name_B2.tif, etc.
            out_file <- file.path(output_dir, paste0(base_name_no_ext, "_", band_code, ".tif"))

            cmd <- sprintf("gdal_translate -b %d '%s' '%s'",
                i, tif_file, out_file)

            exit_code <- system(cmd)

            if (exit_code != 0) {
                cat("  ERROR: Failed to extract band", band_code, "from", basename(tif_file), "\n")
                cat("  Command:", cmd, "\n")
                stop("gdal_translate failed with exit code ", exit_code)
            }
        }
    }
    
    cat("  Done!\n\n")
}

cat("==============================================\n")
cat("Processing complete!\n")
cat("\nTo create a sits cube, run:\n\n")
cat('library(sits)\n\n')
cat('planet_cube <- sits_cube(\n')
cat('  source = "PLANET",\n')
cat('  collection = "MOSAIC-8B",\n')
cat('  data_dir = "', output_dir, '",\n', sep = "")
cat('  parse_info = c("date", "X1", "X2", "tile", "X3", "X4", "X5", "X6", "X7", "X8", "band"),\n')
cat('  delim = "_"\n')
cat(')\n')
