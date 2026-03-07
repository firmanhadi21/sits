# PlanetScope Data Processing Workflow

This document describes the complete workflow for processing PlanetScope 8-band imagery using the `sits` package for land cover classification.

## Overview

This workflow processes PlanetScope PSB.SD 8-band Surface Reflectance data from 2023-2025, creating mosaicked time series, spectral indices, and classification-ready data cubes.

## Dataset Summary

**Temporal Coverage:** January 2023 - November 2025
**Dates Available:** 19 dates
**Spatial Coverage:** UTM Zone 48S
**Resolution:** 3m
**Bands:** 8 spectral bands (Coastal Blue to NIR)

### Timeline

| Year | Dates |
|------|-------|
| 2023 | Jan 14, May 28, Jun 26, Jul 31, Aug 23, Sep 26, Oct 29, Dec 22 (8 dates) |
| 2024 | Jul 14, Aug 05, Sep 16, Oct 29 (4 dates) |
| 2025 | Jan 10, May 05, Jun 08, Aug 15, Sep 07, Sep 22, Nov 24 (7 dates) |

### PlanetScope 8-Band Specification

| Band | Name | Wavelength (nm) | Purpose |
|------|------|-----------------|---------|
| B1 | Coastal Blue | 431-452 | Coastal/aerosol studies |
| B2 | Blue | 465-515 | Water penetration, soil/vegetation discrimination |
| B3 | Green I | 513-549 | Vegetation vigor |
| B4 | Green | 547-583 | Vegetation peak reflectance |
| B5 | Yellow | 600-620 | Vegetation stress, sediment |
| B6 | Red | 650-680 | Chlorophyll absorption |
| B7 | Red Edge | 697-713 | Vegetation health, forest types |
| B8 | NIR | 845-885 | Biomass, water bodies |

## Directory Structure

```
data/
├── planetscope/                    # Raw ZIP files (36 scenes)
├── planetscope_processed/          # Extracted individual bands (288 files)
├── planetscope_mosaicked/          # Date-based mosaics (152 files: 19 dates × 8 bands)
├── planetscope_rgb/                # RGB composites (19 files)
├── planetscope_indices/            # Spectral indices (152 files: 19 dates × 8 indices)
│   ├── NDVI/                       # Normalized Difference Vegetation Index
│   ├── NDWI/                       # Normalized Difference Water Index
│   ├── NDRE/                       # Normalized Difference Red Edge
│   ├── EVI/                        # Enhanced Vegetation Index
│   ├── SAVI/                       # Soil Adjusted Vegetation Index
│   ├── GNDVI/                      # Green NDVI
│   ├── BSI/                        # Bare Soil Index
│   └── NDTI/                       # Normalized Difference Tillage Index
├── planetscope_combined/           # Bands + Indices combined (304 files: 19 dates × 16 bands)
├── clustering_results/             # Unsupervised clustering outputs
│   ├── suggested_sample_points.csv
│   └── suggested_sample_points.gpkg
└── classification_results/         # Classification outputs (to be created)

scripts/
├── process_planetscope.R           # Extract and split bands from ZIP files
├── mosaic_by_date.R                # Create mosaics for each date
├── create_rgb_composites.R         # Create RGB true color composites
├── create_index_composites.R       # Calculate spectral indices
├── create_full_cube.R              # Create sits cubes with bands + indices
├── simple_clustering.R             # Unsupervised clustering for sample selection
├── classify_planetscope.R          # Supervised classification (template)
├── prepare_training_samples.R      # Training sample preparation utilities
├── calculate_indices.R             # Index calculation functions
├── temporal_features.R             # Temporal statistics calculation
└── unsupervised_clustering.R       # Advanced clustering (sits-based)
```

## Processing Workflow

### Step 1: Extract and Process Raw Data

**Script:** `scripts/process_planetscope.R`

Extracts 8-band GeoTIFF files from PlanetScope ZIP archives and splits them into individual band files.

```bash
Rscript scripts/process_planetscope.R data/planetscope/ data/planetscope_processed/
```

**Input:** 36 ZIP files (multiple scenes per date)
**Output:** 288 single-band GeoTIFF files
**File naming:** `YYYYMMDD_HHMMSS_SS_SSSS_3B_AnalyticMS_SR_8b_harmonized_clip_BX.tif`

### Step 2: Create Date-Based Mosaics

**Script:** `scripts/mosaic_by_date.R`

Mosaics multiple scenes from the same date into seamless coverage.

```bash
Rscript scripts/mosaic_by_date.R
```

**Input:** 288 processed band files
**Output:** 152 mosaicked files (19 dates × 8 bands)
**File naming:** `YYYYMMDD_BX.tif`
**Method:** GDAL merge with LZW compression

**Mosaicking Summary:**
- Dates with 1 scene: Copied directly (7 dates)
- Dates with 2-6 scenes: Mosaicked using gdal_merge.py (12 dates)

### Step 3: Create RGB True Color Composites

**Script:** `scripts/create_rgb_composites.R`

Creates RGB composites for visual interpretation (Band 6=Red, Band 4=Green, Band 2=Blue).

```bash
Rscript scripts/create_rgb_composites.R
```

**Input:** Mosaicked bands (B2, B4, B6)
**Output:** 19 RGB GeoTIFF files
**File naming:** `YYYYMMDD_RGB.tif`
**Size:** 47-145 MB per file

### Step 4: Calculate Spectral Indices

**Script:** `scripts/create_index_composites.R`

Calculates 8 spectral indices for each date.

```bash
Rscript scripts/create_index_composites.R
```

**Output:** 152 index files (19 dates × 8 indices)
**Total Size:** ~18 GB
**Format:** 32-bit Float GeoTIFF with LZW compression

**Indices Calculated:**

| Index | Formula | Range | Purpose |
|-------|---------|-------|---------|
| NDVI | (NIR - Red) / (NIR + Red) | -1 to 1 | Vegetation vigor |
| NDWI | (Green - NIR) / (Green + NIR) | -1 to 1 | Water content |
| NDRE | (NIR - RedEdge) / (NIR + RedEdge) | -1 to 1 | Forest health, chlorophyll |
| EVI | 2.5 × ((NIR - Red) / (NIR + 6×Red - 7.5×Blue + 1)) | -1 to 1 | Enhanced vegetation |
| SAVI | ((NIR - Red) / (NIR + Red + L)) × (1 + L) | -1 to 1.5 | Soil-adjusted vegetation |
| GNDVI | (NIR - Green) / (NIR + Green) | -1 to 1 | Green NDVI |
| BSI | ((Red + Green) - (NIR + Blue)) / ((Red + Green) + (NIR + Blue)) | -1 to 1 | Bare soil |
| NDTI | (Red - Green) / (Red + Green) | -1 to 1 | Tillage/bare soil |

### Step 5: Create sits Cubes

**Script:** `scripts/create_full_cube.R`

Creates sits data cubes for time series analysis and classification.

```bash
Rscript scripts/create_full_cube.R
```

**Outputs:**

1. **Bands-only cube** (8 bands)
   - Location: `data/planetscope_mosaicked/`
   - Saved: `data/cube_bands_only.rds`

2. **Combined cube** (16 bands: 8 original + 8 indices)
   - Location: `data/planetscope_combined/`
   - Saved: `data/cube_bands_indices.rds`
   - **Recommended for classification**

**Load cubes in R:**
```r
# Bands only
cube <- readRDS('data/cube_bands_only.rds')

# Bands + indices (recommended)
cube <- readRDS('data/cube_bands_indices.rds')

# Or create fresh:
cube <- sits_cube(
    source = 'PLANET',
    collection = 'MOSAIC-8B',
    data_dir = 'data/planetscope_combined',
    parse_info = c('date', 'tile', 'band'),
    delim = '_',
    bands = c('B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8',
              'NDVI', 'NDWI', 'NDRE', 'EVI', 'SAVI', 'GNDVI', 'BSI', 'NDTI')
)
```

### Step 6: Unsupervised Clustering for Sample Selection

**Script:** `scripts/simple_clustering.R`

Performs K-means clustering to identify strategic sampling locations.

```bash
Rscript scripts/simple_clustering.R
```

**Parameters:**
- Clusters: 10
- Sample size: 2,000 random pixels
- Points per cluster: 20

**Outputs:**
- `data/clustering_results/suggested_sample_points.csv`
- `data/clustering_results/suggested_sample_points.gpkg` (187 points)

**Clustering Results:**

| Cluster | Type | NDVI Range | Pixel Count |
|---------|------|------------|-------------|
| C1-C4, C6-C10 | Forest/Dense Vegetation | 0.60-0.84 | 1,873 |
| C5 | Moderate Vegetation | 0.47 | 30 |

**Note:** Study area is predominantly forested. Additional samples needed for:
- Water bodies
- Settlements/built-up areas
- Bare land
- Agricultural areas
- Sparse vegetation

## Classification Workflow

### 1. Prepare Training Samples

**Option A: Use clustering results as starting point**

```r
library(sf)
library(sits)

# Load suggested sample points
samples <- st_read('data/clustering_results/suggested_sample_points.gpkg')

# Review in QGIS and update labels
# Add columns: label, start_date, end_date
# Save as: data/training_samples.gpkg
```

**Option B: Manually digitize in QGIS**

1. Load RGB composites as reference
2. Create new GeoPackage layer
3. Add fields: `label` (text), `start_date` (date), `end_date` (date)
4. Digitize training points/polygons
5. Save as `data/training_samples.gpkg`

**Recommended classes:**
- `natural_forest`
- `production_forest`
- `agroforest`
- `paddy`
- `ladang` (shifting cultivation)
- `grassland`
- `sparse_vegetation`
- `bareland`
- `settlement`
- `water`

### 2. Extract Training Time Series

```r
library(sits)
library(sf)

# Load cube
cube <- readRDS('data/cube_bands_indices.rds')

# Load training samples
samples_sf <- st_read('data/training_samples.gpkg')

# Extract time series
training_data <- sits_get_data(cube, samples_sf)

# Check sample distribution
table(training_data$label)

# Validate samples (optional)
source('scripts/prepare_training_samples.R')
validate_training_samples('data/training_samples.gpkg', cube)
```

### 3. Train Classification Model

```r
# Train Random Forest model
model_rf <- sits_train(
    samples = training_data,
    ml_method = sits_rfor(num_trees = 500)
)

# Or try XGBoost
model_xgb <- sits_train(
    samples = training_data,
    ml_method = sits_xgboost(nrounds = 100)
)

# Cross-validation
accuracy <- sits_kfold_validate(
    samples = training_data,
    folds = 5,
    ml_method = sits_rfor(num_trees = 500)
)

print(accuracy)

# Save model
saveRDS(model_rf, 'data/classification_results/model_rf.rds')
```

### 4. Classify the Cube

```r
# Create output directory
dir.create('data/classification_results', recursive = TRUE, showWarnings = FALSE)

# Classify cube
classified <- sits_classify(
    data = cube,
    ml_model = model_rf,
    output_dir = 'data/classification_results',
    memsize = 8,
    multicores = 4,
    version = 'v1'
)

# Apply Bayesian smoothing to remove outliers
smoothed <- sits_smooth(
    cube = classified,
    output_dir = 'data/classification_results',
    memsize = 8,
    multicores = 4,
    version = 'v1'
)

# Generate labeled map
labeled <- sits_label_classification(
    cube = smoothed,
    output_dir = 'data/classification_results',
    version = 'v1'
)

# Visualize
plot(labeled)
```

### 5. Accuracy Assessment

```r
# Load validation samples (separate from training)
validation_sf <- st_read('data/validation_samples.gpkg')

# Extract predictions at validation points
validation_ts <- sits_get_data(labeled, validation_sf)

# Calculate confusion matrix
accuracy_assessment <- sits_accuracy(validation_ts)

print(accuracy_assessment)
```

## Visualization in QGIS

### Load RGB Composites

```python
# QGIS Python Console
import os
from qgis.core import QgsRasterLayer, QgsProject

rgb_dir = 'data/planetscope_rgb'
for file in sorted(os.listdir(rgb_dir)):
    if file.endswith('_RGB.tif'):
        path = os.path.join(rgb_dir, file)
        layer = QgsRasterLayer(path, file[:-4])
        QgsProject.instance().addMapLayer(layer)
```

**Or manually:**
1. Layer → Add Layer → Add Raster Layer
2. Navigate to `data/planetscope_rgb/`
3. Select all RGB files
4. Adjust symbology: Min/max → Cumulative count cut (2-98%)

### Load Spectral Indices

**NDVI (Vegetation):**
1. Load `data/planetscope_indices/NDVI/*.tif`
2. Symbology → Singleband pseudocolor
3. Color ramp: RdYlGn (Red-Yellow-Green)
4. Min: 0, Max: 1
5. Mode: Equal interval

**NDWI (Water):**
1. Load `data/planetscope_indices/NDWI/*.tif`
2. Color ramp: Blues
3. Min: -0.5, Max: 0.5

### Load Sample Points

```python
# Load clustering results
layer = QgsVectorLayer('data/clustering_results/suggested_sample_points.gpkg',
                       'Sample Points', 'ogr')
QgsProject.instance().addMapLayer(layer)

# Style by cluster
from qgis.core import QgsCategorizedSymbolRenderer
# Right-click layer → Properties → Symbology → Categorized
# Value: cluster
# Classify
```

### Temporal Animation

1. Open Temporal Controller panel
2. Add all RGB layers or index layers
3. Configure time settings
4. Animate through dates

## Data Processing Notes

### Important Considerations

**No Regularization Needed for Classification:**
- All 19 dates share the same irregular timeline
- Pre-calculated indices avoid gdalcubes issues
- Supervised classification (sits_train/sits_classify) works directly with irregular cubes
- Training samples extracted from the same cube have matching timelines

**When Regularization IS Needed:**
- Dynamic index calculation with `sits_apply()` (uses gdalcubes)
- Deep learning models requiring fixed input dimensions
- Merging data from different sensors with different acquisition schedules

**File Naming Conventions:**
- Mosaicked bands: `YYYYMMDD_BX.tif`
- RGB composites: `YYYYMMDD_RGB.tif`
- Indices: `YYYYMMDD_INDEXNAME.tif`
- Combined cube: `YYYYMMDD_TILE_BAND.tif` (symbolic links)

### Performance Tips

1. **Use combined cube (bands + indices)** for better classification accuracy
2. **Select relevant bands** to reduce processing time if needed
3. **Adjust memory/multicores** based on available resources:
   - `memsize`: 8-16 GB recommended
   - `multicores`: 4-8 cores recommended
4. **Use sits_regularize() only if** calculating indices dynamically with sits_apply()

## Quality Control

### Data Quality Checks

```r
# Check cube integrity
cube <- readRDS('data/cube_bands_indices.rds')
sits_timeline(cube)  # Should show 19 dates
sits_bands(cube)     # Should show 16 bands
sits_bbox(cube)      # Check spatial extent

# Verify all bands exist for all dates
for (date in sits_timeline(cube)) {
    files <- list.files('data/planetscope_combined',
                       pattern = paste0(date, "_TILE_"),
                       full.names = TRUE)
    cat(date, ":", length(files), "bands\n")
}
```

### Sample Quality Control

```r
# Use Self-Organizing Maps for sample cleaning
source('scripts/explore_with_som.R')

# Analyze sample separability
library(sits)
sits_som_evaluate_cluster(training_data)
```

## Troubleshooting

### Common Issues

**Issue:** `Error: cube is not regular - run sits_regularize() first`
**Solution:** Only needed for sits_apply(). For classification, use pre-calculated indices.

**Issue:** `gdalcubes C++ exception (unknown reason)`
**Solution:** Reduce multicores to 1, or avoid regularization by using pre-calculated indices.

**Issue:** Insufficient training samples
**Solution:** Add more samples for underrepresented classes (target: 50+ per class).

**Issue:** Low classification accuracy
**Solution:**
- Use combined cube (bands + indices)
- Add temporal features
- Increase training samples
- Try different ML algorithms
- Apply smoothing post-processing

## Storage Requirements

| Data Product | Files | Total Size |
|--------------|-------|------------|
| Raw ZIPs | 36 | ~12 GB |
| Processed bands | 288 | ~8 GB |
| Mosaicked bands | 152 | ~5 GB |
| RGB composites | 19 | ~2.3 GB |
| Spectral indices | 152 | ~18 GB |
| Combined cube (symlinks) | 304 | ~23 GB |
| **Total** | | **~45 GB** |

## References

### Software

- **sits**: Simoes et al. (2021). Satellite Image Time Series Analysis for Big Earth Observation Data. Remote Sensing 13(13):2428.
- **gdalcubes**: Appel & Pebesma (2019). On-Demand Processing of Data Cubes from Satellite Image Collections with the gdalcubes Library.

### PlanetScope Data

- Planet Labs PBC (2023). Planet Imagery Product Specifications.
- Surface Reflectance Product: Atmospherically corrected, harmonized 8-band data.

## Contact & Support

For issues specific to this workflow, refer to the scripts in `scripts/` directory.
For sits package issues, see: https://github.com/e-sensing/sits

---

**Last Updated:** March 2026
**Data Version:** PlanetScope 8-band SR (2023-2025)
**Processing Version:** 1.0
