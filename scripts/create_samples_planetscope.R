#!/usr/bin/env Rscript
# Create template training samples for PlanetScope hierarchical classification
#
# Outputs:
#   data/samples_planet_step1_landcover.gpkg
#   data/samples_planet_step2_dense_vegetation.gpkg
#   data/samples_planet_step3_sparse_vegetation.gpkg
#
# INSTRUCTIONS:
#   1. Run this script to generate templates with placeholder coordinates
#   2. Open each .gpkg in QGIS alongside your PlanetScope imagery
#   3. Move/add points to actual locations matching each class
#   4. Aim for at least 50 points per class (more is better)
#   5. Save and run scripts/hierarchical_classification.R

suppressPackageStartupMessages({
    library(sf)
})

cat("========================================\n")
cat("Training Sample Templates - PlanetScope\n")
cat("3-Step Hierarchical Classification\n")
cat("========================================\n\n")

# ==============================================================================
# Study area (Cisokan, West Java)
# ==============================================================================

BASE_LON <- 106.53
BASE_LAT <- -7.12

# PlanetScope timeline
START_DATE <- as.Date("2023-01-14")
END_DATE   <- as.Date("2025-11-24")

OUTPUT_PREFIX <- "data/samples_planet"

cat("  Date range:", format(START_DATE), "to", format(END_DATE), "\n")
cat("  Output prefix:", OUTPUT_PREFIX, "\n\n")

# ==============================================================================
# Step 1: Broad land cover (7 classes)
# ==============================================================================

cat("Creating Step 1: Broad Land Cover (7 classes)\n")

step1 <- data.frame(
    longitude = c(
        # water (rivers, reservoirs, ponds)
        BASE_LON + 0.001, BASE_LON + 0.002, BASE_LON + 0.003,
        BASE_LON + 0.004, BASE_LON + 0.005,
        # paddy (irrigated rice fields)
        BASE_LON + 0.010, BASE_LON + 0.011, BASE_LON + 0.012,
        BASE_LON + 0.013, BASE_LON + 0.014,
        # ladang (dryland agriculture / shifting cultivation)
        BASE_LON + 0.020, BASE_LON + 0.021, BASE_LON + 0.022,
        BASE_LON + 0.023, BASE_LON + 0.024,
        # sparse_vegetation (shrubs, grassland, degraded areas)
        BASE_LON + 0.030, BASE_LON + 0.031, BASE_LON + 0.032,
        BASE_LON + 0.033, BASE_LON + 0.034,
        # dense_vegetation (forests, agroforestry, plantations)
        BASE_LON + 0.040, BASE_LON + 0.041, BASE_LON + 0.042,
        BASE_LON + 0.043, BASE_LON + 0.044,
        # built_up (settlements, roads, infrastructure)
        BASE_LON + 0.050, BASE_LON + 0.051, BASE_LON + 0.052,
        BASE_LON + 0.053, BASE_LON + 0.054,
        # bareland (exposed soil, mines, cleared land)
        BASE_LON + 0.060, BASE_LON + 0.061, BASE_LON + 0.062,
        BASE_LON + 0.063, BASE_LON + 0.064
    ),
    latitude = c(
        BASE_LAT + 0.001, BASE_LAT + 0.002, BASE_LAT + 0.003,
        BASE_LAT + 0.004, BASE_LAT + 0.005,
        BASE_LAT - 0.001, BASE_LAT - 0.002, BASE_LAT - 0.003,
        BASE_LAT - 0.004, BASE_LAT - 0.005,
        BASE_LAT + 0.010, BASE_LAT + 0.011, BASE_LAT + 0.012,
        BASE_LAT + 0.013, BASE_LAT + 0.014,
        BASE_LAT - 0.010, BASE_LAT - 0.011, BASE_LAT - 0.012,
        BASE_LAT - 0.013, BASE_LAT - 0.014,
        BASE_LAT + 0.020, BASE_LAT + 0.021, BASE_LAT + 0.022,
        BASE_LAT + 0.023, BASE_LAT + 0.024,
        BASE_LAT - 0.020, BASE_LAT - 0.021, BASE_LAT - 0.022,
        BASE_LAT - 0.023, BASE_LAT - 0.024,
        BASE_LAT + 0.030, BASE_LAT + 0.031, BASE_LAT + 0.032,
        BASE_LAT + 0.033, BASE_LAT + 0.034
    ),
    label = c(
        rep("water", 5), rep("paddy", 5), rep("ladang", 5),
        rep("sparse_vegetation", 5), rep("dense_vegetation", 5),
        rep("built_up", 5), rep("bareland", 5)
    ),
    start_date = rep(START_DATE, 35),
    end_date   = rep(END_DATE, 35),
    notes = c(
        "River", "Reservoir/dam", "Fish pond", "Irrigation canal", "Lake/pond",
        "Irrigated rice - lowland", "Irrigated rice - terrace",
        "Irrigated rice - valley", "Irrigated rice - flat",
        "Irrigated rice - near river",
        "Dryland crops - hillside", "Dryland crops - mixed",
        "Shifting cultivation - active", "Shifting cultivation - fallow",
        "Dryland crops - vegetables",
        "Shrubland", "Degraded grassland", "Young regrowth",
        "Sparse scrub", "Open grass area",
        "Natural forest - primary", "Natural forest - secondary",
        "Production forest - timber", "Agroforest - mixed",
        "Agroforest - rubber/coffee",
        "Village settlement", "Road/infrastructure",
        "Industrial/commercial", "Dam facilities", "School/public building",
        "Exposed soil - cleared", "Mining/quarry", "Construction site",
        "Eroded slope", "Dry riverbed"
    ),
    stringsAsFactors = FALSE
)

step1_sf <- st_as_sf(step1, coords = c("longitude", "latitude"), crs = 4326)
st_write(step1_sf, paste0(OUTPUT_PREFIX, "_step1_landcover.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
write.csv(step1, paste0(OUTPUT_PREFIX, "_step1_landcover.csv"), row.names = FALSE)

cat("  Created:", paste0(OUTPUT_PREFIX, "_step1_landcover.gpkg"), "\n")
cat("  Points: 35 (5 per class x 7 classes)\n\n")

# ==============================================================================
# Step 2: Dense vegetation sub-classes (3 classes)
# ==============================================================================

cat("Creating Step 2: Dense Vegetation (3 classes)\n")

step2 <- data.frame(
    longitude = c(
        BASE_LON + 0.040, BASE_LON + 0.041, BASE_LON + 0.042,
        BASE_LON + 0.043, BASE_LON + 0.044,
        BASE_LON + 0.045, BASE_LON + 0.046, BASE_LON + 0.047,
        BASE_LON + 0.048, BASE_LON + 0.049,
        BASE_LON + 0.050, BASE_LON + 0.051, BASE_LON + 0.052,
        BASE_LON + 0.053, BASE_LON + 0.054
    ),
    latitude = c(
        BASE_LAT + 0.040, BASE_LAT + 0.041, BASE_LAT + 0.042,
        BASE_LAT + 0.043, BASE_LAT + 0.044,
        BASE_LAT + 0.045, BASE_LAT + 0.046, BASE_LAT + 0.047,
        BASE_LAT + 0.048, BASE_LAT + 0.049,
        BASE_LAT + 0.050, BASE_LAT + 0.051, BASE_LAT + 0.052,
        BASE_LAT + 0.053, BASE_LAT + 0.054
    ),
    label = c(
        rep("natural_forest", 5),
        rep("production_forest", 5),
        rep("agroforest", 5)
    ),
    start_date = rep(START_DATE, 15),
    end_date   = rep(END_DATE, 15),
    notes = c(
        "Primary forest - undisturbed canopy",
        "Primary forest - ridge top",
        "Secondary forest - mature regrowth",
        "Secondary forest - riparian/stream buffer",
        "Natural forest - steep slope",
        "Timber plantation - pine (Pinus merkusii)",
        "Timber plantation - mahogany (Swietenia)",
        "Timber plantation - teak (Tectona grandis)",
        "Timber plantation - eucalyptus",
        "Timber plantation - mixed commercial species",
        "Agroforest - rubber (Hevea brasiliensis)",
        "Agroforest - coffee under shade trees",
        "Agroforest - cacao under shade trees",
        "Agroforest - mixed fruit trees",
        "Agroforest - clove/nutmeg with shade"
    ),
    stringsAsFactors = FALSE
)

step2_sf <- st_as_sf(step2, coords = c("longitude", "latitude"), crs = 4326)
st_write(step2_sf, paste0(OUTPUT_PREFIX, "_step2_dense_vegetation.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
write.csv(step2, paste0(OUTPUT_PREFIX, "_step2_dense_vegetation.csv"), row.names = FALSE)

cat("  Created:", paste0(OUTPUT_PREFIX, "_step2_dense_vegetation.gpkg"), "\n")
cat("  Points: 15 (5 per class x 3 classes)\n")
cat("  -> All points MUST be within dense_vegetation areas\n\n")

# ==============================================================================
# Step 3: Sparse vegetation sub-classes (2 classes)
# ==============================================================================

cat("Creating Step 3: Sparse Vegetation (2 classes)\n")

step3 <- data.frame(
    longitude = c(
        BASE_LON + 0.030, BASE_LON + 0.031, BASE_LON + 0.032,
        BASE_LON + 0.033, BASE_LON + 0.034,
        BASE_LON + 0.035, BASE_LON + 0.036, BASE_LON + 0.037,
        BASE_LON + 0.038, BASE_LON + 0.039
    ),
    latitude = c(
        BASE_LAT - 0.030, BASE_LAT - 0.031, BASE_LAT - 0.032,
        BASE_LAT - 0.033, BASE_LAT - 0.034,
        BASE_LAT - 0.035, BASE_LAT - 0.036, BASE_LAT - 0.037,
        BASE_LAT - 0.038, BASE_LAT - 0.039
    ),
    label = c(rep("shrubs", 5), rep("grassland", 5)),
    start_date = rep(START_DATE, 10),
    end_date   = rep(END_DATE, 10),
    notes = c(
        "Woody shrubland - dense scrub",
        "Young secondary growth - 2-5 years",
        "Bush/scrub on degraded slope",
        "Shrubs along road/clearing edge",
        "Mixed shrubs - scattered small trees",
        "Open grassland - alang-alang (Imperata)",
        "Pasture/grazing land",
        "Grass on cleared slope",
        "Grass meadow - valley bottom",
        "Grass on abandoned agricultural land"
    ),
    stringsAsFactors = FALSE
)

step3_sf <- st_as_sf(step3, coords = c("longitude", "latitude"), crs = 4326)
st_write(step3_sf, paste0(OUTPUT_PREFIX, "_step3_sparse_vegetation.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)
write.csv(step3, paste0(OUTPUT_PREFIX, "_step3_sparse_vegetation.csv"), row.names = FALSE)

cat("  Created:", paste0(OUTPUT_PREFIX, "_step3_sparse_vegetation.gpkg"), "\n")
cat("  Points: 10 (5 per class x 2 classes)\n")
cat("  -> All points MUST be within sparse_vegetation areas\n\n")

# ==============================================================================
# Summary
# ==============================================================================

cat("========================================\n")
cat("PlanetScope Sample Templates Created!\n")
cat("========================================\n\n")

cat("Files (.gpkg + .csv):\n")
cat("  ", paste0(OUTPUT_PREFIX, "_step1_landcover.*"), "\n")
cat("  ", paste0(OUTPUT_PREFIX, "_step2_dense_vegetation.*"), "\n")
cat("  ", paste0(OUTPUT_PREFIX, "_step3_sparse_vegetation.*"), "\n\n")

cat("Date range: 2023-01-14 to 2025-11-24 (same for all samples)\n\n")

cat("Edit in QGIS, then run:\n")
cat("  source('scripts/hierarchical_classification.R')\n")
