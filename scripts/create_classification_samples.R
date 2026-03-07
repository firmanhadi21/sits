#!/usr/bin/env Rscript
# Create template training sample GeoPackages for 3-step hierarchical classification
#
# Outputs:
#   data/samples_step1_landcover.gpkg
#   data/samples_step2_dense_vegetation.gpkg
#   data/samples_step3_sparse_vegetation.gpkg
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
cat("Training Sample Template Creator\n")
cat("3-Step Hierarchical Classification\n")
cat("========================================\n\n")

# ==============================================================================
# Study area reference (Cisokan, West Java - UTM 48S)
# Adjust these base coordinates to your actual study area
# ==============================================================================

# Base coordinates (approximate center of study area)
BASE_LON <- 106.53
BASE_LAT <- -7.12

# Date range matching your PlanetScope data
START_DATE <- as.Date("2023-01-01")
END_DATE   <- as.Date("2025-12-31")

# ==============================================================================
# Step 1: Broad land cover (7 classes)
# ==============================================================================

cat("Creating Step 1 template: Broad Land Cover (7 classes)\n")
cat("  Classes: water, paddy, ladang, sparse_vegetation,\n")
cat("           dense_vegetation, built_up, bareland\n\n")

# 5 template points per class = 35 points
# In practice you need 50+ per class — add more in QGIS
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
        # water
        BASE_LAT + 0.001, BASE_LAT + 0.002, BASE_LAT + 0.003,
        BASE_LAT + 0.004, BASE_LAT + 0.005,
        # paddy
        BASE_LAT - 0.001, BASE_LAT - 0.002, BASE_LAT - 0.003,
        BASE_LAT - 0.004, BASE_LAT - 0.005,
        # ladang
        BASE_LAT + 0.010, BASE_LAT + 0.011, BASE_LAT + 0.012,
        BASE_LAT + 0.013, BASE_LAT + 0.014,
        # sparse_vegetation
        BASE_LAT - 0.010, BASE_LAT - 0.011, BASE_LAT - 0.012,
        BASE_LAT - 0.013, BASE_LAT - 0.014,
        # dense_vegetation
        BASE_LAT + 0.020, BASE_LAT + 0.021, BASE_LAT + 0.022,
        BASE_LAT + 0.023, BASE_LAT + 0.024,
        # built_up
        BASE_LAT - 0.020, BASE_LAT - 0.021, BASE_LAT - 0.022,
        BASE_LAT - 0.023, BASE_LAT - 0.024,
        # bareland
        BASE_LAT + 0.030, BASE_LAT + 0.031, BASE_LAT + 0.032,
        BASE_LAT + 0.033, BASE_LAT + 0.034
    ),
    label = c(
        rep("water", 5),
        rep("paddy", 5),
        rep("ladang", 5),
        rep("sparse_vegetation", 5),
        rep("dense_vegetation", 5),
        rep("built_up", 5),
        rep("bareland", 5)
    ),
    start_date = rep(START_DATE, 35),
    end_date   = rep(END_DATE, 35),
    notes = c(
        # water
        "River", "Reservoir/dam", "Fish pond", "Irrigation canal", "Lake/pond",
        # paddy
        "Irrigated rice - lowland", "Irrigated rice - terrace",
        "Irrigated rice - valley", "Irrigated rice - flat",
        "Irrigated rice - near river",
        # ladang
        "Dryland crops - hillside", "Dryland crops - mixed",
        "Shifting cultivation - active", "Shifting cultivation - fallow",
        "Dryland crops - vegetables",
        # sparse_vegetation
        "Shrubland", "Degraded grassland", "Young regrowth",
        "Sparse scrub", "Open grass area",
        # dense_vegetation
        "Natural forest - primary", "Natural forest - secondary",
        "Production forest - timber", "Agroforest - mixed",
        "Agroforest - rubber/coffee",
        # built_up
        "Village settlement", "Road/infrastructure",
        "Industrial/commercial", "Dam facilities", "School/public building",
        # bareland
        "Exposed soil - cleared", "Mining/quarry", "Construction site",
        "Eroded slope", "Dry riverbed"
    ),
    stringsAsFactors = FALSE
)

step1_sf <- st_as_sf(step1, coords = c("longitude", "latitude"), crs = 4326)
st_write(step1_sf, "data/samples_step1_landcover.gpkg",
         delete_dsn = TRUE, quiet = TRUE)

cat("  Created: data/samples_step1_landcover.gpkg\n")
cat("  Template points:", nrow(step1_sf), "(5 per class x 7 classes)\n")
cat("  -> Add more points in QGIS (aim for 50+ per class)\n\n")

# ==============================================================================
# Step 2: Dense vegetation sub-classes (3 classes)
# ==============================================================================

cat("Creating Step 2 template: Dense Vegetation (3 classes)\n")
cat("  Classes: natural_forest, production_forest, agroforest\n\n")

# 5 template points per class = 15 points
step2 <- data.frame(
    longitude = c(
        # natural_forest (primary/secondary natural forest, high canopy, diverse species)
        BASE_LON + 0.040, BASE_LON + 0.041, BASE_LON + 0.042,
        BASE_LON + 0.043, BASE_LON + 0.044,
        # production_forest (timber plantations, pine, eucalyptus, teak, mahogany)
        BASE_LON + 0.045, BASE_LON + 0.046, BASE_LON + 0.047,
        BASE_LON + 0.048, BASE_LON + 0.049,
        # agroforest (mixed tree crops: rubber, coffee, cacao, fruit trees)
        BASE_LON + 0.050, BASE_LON + 0.051, BASE_LON + 0.052,
        BASE_LON + 0.053, BASE_LON + 0.054
    ),
    latitude = c(
        # natural_forest
        BASE_LAT + 0.040, BASE_LAT + 0.041, BASE_LAT + 0.042,
        BASE_LAT + 0.043, BASE_LAT + 0.044,
        # production_forest
        BASE_LAT + 0.045, BASE_LAT + 0.046, BASE_LAT + 0.047,
        BASE_LAT + 0.048, BASE_LAT + 0.049,
        # agroforest
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
        # natural_forest
        "Primary forest - undisturbed canopy",
        "Primary forest - ridge top",
        "Secondary forest - mature regrowth",
        "Secondary forest - riparian/stream buffer",
        "Natural forest - steep slope",
        # production_forest
        "Timber plantation - pine (Pinus merkusii)",
        "Timber plantation - mahogany (Swietenia)",
        "Timber plantation - teak (Tectona grandis)",
        "Timber plantation - eucalyptus",
        "Timber plantation - mixed commercial species",
        # agroforest
        "Agroforest - rubber (Hevea brasiliensis)",
        "Agroforest - coffee under shade trees",
        "Agroforest - cacao under shade trees",
        "Agroforest - mixed fruit trees",
        "Agroforest - clove/nutmeg with shade"
    ),
    stringsAsFactors = FALSE
)

step2_sf <- st_as_sf(step2, coords = c("longitude", "latitude"), crs = 4326)
st_write(step2_sf, "data/samples_step2_dense_vegetation.gpkg",
         delete_dsn = TRUE, quiet = TRUE)

cat("  Created: data/samples_step2_dense_vegetation.gpkg\n")
cat("  Template points:", nrow(step2_sf), "(5 per class x 3 classes)\n")
cat("  -> Add more points in QGIS (aim for 50+ per class)\n")
cat("  -> All points MUST be within dense_vegetation areas\n\n")

# ==============================================================================
# Step 3: Sparse vegetation sub-classes (2 classes)
# ==============================================================================

cat("Creating Step 3 template: Sparse Vegetation (2 classes)\n")
cat("  Classes: shrubs, grassland\n\n")

# 5 template points per class = 10 points
step3 <- data.frame(
    longitude = c(
        # shrubs (woody shrubland, young secondary growth, bush/scrub)
        BASE_LON + 0.030, BASE_LON + 0.031, BASE_LON + 0.032,
        BASE_LON + 0.033, BASE_LON + 0.034,
        # grassland (open grass, pasture, meadow, alang-alang)
        BASE_LON + 0.035, BASE_LON + 0.036, BASE_LON + 0.037,
        BASE_LON + 0.038, BASE_LON + 0.039
    ),
    latitude = c(
        # shrubs
        BASE_LAT - 0.030, BASE_LAT - 0.031, BASE_LAT - 0.032,
        BASE_LAT - 0.033, BASE_LAT - 0.034,
        # grassland
        BASE_LAT - 0.035, BASE_LAT - 0.036, BASE_LAT - 0.037,
        BASE_LAT - 0.038, BASE_LAT - 0.039
    ),
    label = c(
        rep("shrubs", 5),
        rep("grassland", 5)
    ),
    start_date = rep(START_DATE, 10),
    end_date   = rep(END_DATE, 10),
    notes = c(
        # shrubs
        "Woody shrubland - dense scrub",
        "Young secondary growth - 2-5 years",
        "Bush/scrub on degraded slope",
        "Shrubs along road/clearing edge",
        "Mixed shrubs - scattered small trees",
        # grassland
        "Open grassland - alang-alang (Imperata)",
        "Pasture/grazing land",
        "Grass on cleared slope",
        "Grass meadow - valley bottom",
        "Grass on abandoned agricultural land"
    ),
    stringsAsFactors = FALSE
)

step3_sf <- st_as_sf(step3, coords = c("longitude", "latitude"), crs = 4326)
st_write(step3_sf, "data/samples_step3_sparse_vegetation.gpkg",
         delete_dsn = TRUE, quiet = TRUE)

cat("  Created: data/samples_step3_sparse_vegetation.gpkg\n")
cat("  Template points:", nrow(step3_sf), "(5 per class x 2 classes)\n")
cat("  -> Add more points in QGIS (aim for 50+ per class)\n")
cat("  -> All points MUST be within sparse_vegetation areas\n\n")

# ==============================================================================
# Also create CSV versions for easy editing in spreadsheet
# ==============================================================================

write.csv(step1, "data/samples_step1_landcover.csv", row.names = FALSE)
write.csv(step2, "data/samples_step2_dense_vegetation.csv", row.names = FALSE)
write.csv(step3, "data/samples_step3_sparse_vegetation.csv", row.names = FALSE)

cat("CSV versions also created for spreadsheet editing:\n")
cat("  data/samples_step1_landcover.csv\n")
cat("  data/samples_step2_dense_vegetation.csv\n")
cat("  data/samples_step3_sparse_vegetation.csv\n\n")

# ==============================================================================
# Summary and instructions
# ==============================================================================

cat("========================================\n")
cat("Sample Templates Created!\n")
cat("========================================\n\n")

cat("NEXT STEPS:\n\n")

cat("Option A: Edit in QGIS (recommended)\n")
cat("  1. Open QGIS\n")
cat("  2. Load your PlanetScope RGB composites as base layer\n")
cat("  3. Load each .gpkg file as a vector layer\n")
cat("  4. Toggle editing on the layer\n")
cat("  5. Move existing template points to correct locations\n")
cat("  6. Add new points (aim for 50+ per class)\n")
cat("  7. Set the 'label' field correctly for each point\n")
cat("  8. Save edits\n\n")

cat("Option B: Edit CSV in spreadsheet, then convert\n")
cat("  1. Open the .csv files in Excel/LibreOffice\n")
cat("  2. Replace placeholder coordinates with real ones\n")
cat("  3. Add rows for more samples\n")
cat("  4. Save as CSV\n")
cat("  5. Convert back to GeoPackage:\n\n")
cat("     library(sf)\n")
cat("     df <- read.csv('data/samples_step1_landcover.csv')\n")
cat("     sf_obj <- st_as_sf(df, coords = c('longitude', 'latitude'), crs = 4326)\n")
cat("     st_write(sf_obj, 'data/samples_step1_landcover.gpkg',\n")
cat("              delete_dsn = TRUE)\n\n")

cat("GUIDELINES:\n")
cat("  - Minimum 50 points per class (100+ recommended)\n")
cat("  - Spread points across the study area (avoid spatial clustering)\n")
cat("  - Use pure pixels only (avoid edges between classes)\n")
cat("  - Step 2 points must be in areas you'd classify as dense_vegetation\n")
cat("  - Step 3 points must be in areas you'd classify as sparse_vegetation\n")
cat("  - Verify with multi-date imagery when possible\n")
cat("  - Use the 'notes' field to record what you see at each point\n\n")

cat("SAMPLE COUNT TARGETS:\n")
cat("  Step 1 (7 classes):  350+ total (50+ per class)\n")
cat("  Step 2 (3 classes):  150+ total (50+ per class)\n")
cat("  Step 3 (2 classes):  100+ total (50+ per class)\n")
cat("  Grand total:         600+ points\n\n")

cat("When samples are ready, run:\n")
cat("  source('scripts/hierarchical_classification.R')\n")
