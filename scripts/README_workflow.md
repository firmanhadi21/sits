# PlanetScope Classification Workflow with sits

This directory contains scripts for end-to-end processing of PlanetScope 8-band imagery using the `sits` package.

## Overview

The workflow consists of three main steps:

1. **Data Processing**: Convert PlanetScope ZIP files to sits-compatible format
2. **Sample Preparation**: Create and validate training samples
3. **Classification**: Train model and classify imagery

## Scripts

### 1. `process_planetscope.R`

Processes raw PlanetScope ZIP files into sits-compatible format.

**What it does:**
- Extracts 8-band surface reflectance TIFs from ZIP files
- Splits multi-band TIFs into individual band files (B1-B8)
- Creates properly named files for sits cube creation

**Usage:**
```bash
Rscript scripts/process_planetscope.R <input_dir> <output_dir>

# Example:
Rscript scripts/process_planetscope.R data/planetscope/ data/planetscope_processed/
```

**Input:** Directory containing PlanetScope ZIP files
**Output:** Directory with individual band GeoTIFF files

### 2. `prepare_training_samples.R`

Helper functions for creating and validating training samples.

**What it provides:**
- Create samples from CSV (longitude, latitude, label)
- Extract samples from reference classification
- Convert polygon samples to points
- Validate sample quality and distribution

**Usage:**
```r
source("scripts/prepare_training_samples.R")

# Example: Create samples from CSV
samples <- create_samples_from_csv(
    csv_file = "data/training_points.csv",
    output_file = "data/training_samples.gpkg"
)

# Validate samples
validate_training_samples("data/training_samples.gpkg")
```

### 3. `classify_planetscope.R`

End-to-end classification pipeline.

**What it does:**
- Creates sits cube from processed data
- Loads training samples
- Extracts time series for training
- Trains classification model (Random Forest, XGBoost, SVM, or LightGBM)
- Classifies the entire cube
- Applies post-processing (smoothing)
- Generates output maps

**Usage:**
```bash
Rscript scripts/classify_planetscope.R
```

**Configuration:** Edit the script to set:
- `DATA_DIR`: Location of processed PlanetScope data
- `SAMPLES_FILE`: Training samples file (.gpkg, .shp, or .geojson)
- `OUTPUT_DIR`: Where to save results
- `CLASSIFIER`: Algorithm to use ("rf", "xgboost", "svm", "lightgbm")
- `MEMSIZE`: Memory allocation (GB)
- `MULTICORES`: Number of CPU cores to use

## Complete Workflow Example

### Step 1: Process PlanetScope Data

```bash
# Process all ZIP files
Rscript scripts/process_planetscope.R \
    data/planetscope/ \
    data/planetscope_processed/
```

This creates individual band files like:
```
data/planetscope_processed/
├── 20230823_021732_60_24b5_3B_AnalyticMS_SR_8b_harmonized_clip_B1.tif
├── 20230823_021732_60_24b5_3B_AnalyticMS_SR_8b_harmonized_clip_B2.tif
├── ...
└── 20230823_021732_60_24b5_3B_AnalyticMS_SR_8b_harmonized_clip_B8.tif
```

### Step 2: Prepare Training Samples

**Option A: Collect in QGIS**

1. Open QGIS
2. Load one of your PlanetScope images as reference
3. Create a new GeoPackage layer:
   - Layer > Create Layer > New GeoPackage Layer
   - Add a "label" field (text)
4. Digitize training samples (points or polygons)
5. For each sample, set the label (e.g., "forest", "water", "cropland")
6. Save as `data/training_samples.gpkg`

**Option B: From CSV**

Create a CSV file with coordinates:
```csv
longitude,latitude,label
-47.123,10.456,forest
-47.124,10.457,water
-47.125,10.458,cropland
```

Then convert to GeoPackage:
```r
source("scripts/prepare_training_samples.R")

samples <- create_samples_from_csv(
    csv_file = "data/training_points.csv",
    output_file = "data/training_samples.gpkg"
)
```

**Validate samples:**
```r
source("scripts/prepare_training_samples.R")
validate_training_samples("data/training_samples.gpkg")
```

### Step 3: Run Classification

```bash
# Edit classify_planetscope.R to set paths and parameters
# Then run:
Rscript scripts/classify_planetscope.R
```

The script will:
1. Create sits cube
2. Load training samples
3. Extract time series
4. Train model with cross-validation
5. Classify the imagery
6. Apply smoothing
7. Generate output maps

**Outputs** (in `data/classification_results/`):
- `*_probs.tif`: Class probability maps
- `*_class.tif`: Final classification map
- `model.rds`: Trained model (can be reused)

### Step 4: Visualize Results

**In R:**
```r
library(sits)

# Load result cube
result <- sits_cube(
    source = "BDC",
    collection = "MOSAIC-8B-CLASS",
    data_dir = "data/classification_results/"
)

# Plot classification
plot(result)
```

**In QGIS:**
1. Open QGIS
2. Add Raster Layer
3. Navigate to `data/classification_results/`
4. Load `*_class.tif` file

## Training Sample Requirements

**Minimum requirements:**
- At least 30-50 samples per class (more is better)
- Samples should be spatially distributed across the study area
- Samples should represent the full temporal range of your data
- Must have a "label" column with class names

**Recommended:**
- 100+ samples per class for robust models
- Include samples from different seasons if available
- Ensure samples are pure (not mixed classes)
- Balance sample sizes across classes

## Tips for Irregular Time Series

Your PlanetScope data has irregular temporal spacing - this is normal and fine!

**sits handles this by:**
- Using the actual observation dates (no interpolation needed)
- Learning patterns from whatever temporal information is available
- Not requiring regular intervals or gap-filling

**What matters:**
- Having multiple observations over time (you have 19 dates ✓)
- Capturing seasonal/phenological patterns
- Having training samples that overlap with your imagery dates

**What doesn't matter:**
- Regular spacing (monthly, weekly, etc.)
- Same number of observations per pixel
- Filling gaps between observations

## Classification Algorithm Comparison

| Algorithm | Speed | Accuracy | Memory | Good For |
|-----------|-------|----------|--------|----------|
| Random Forest (`rf`) | Medium | High | Medium | General purpose, robust |
| XGBoost (`xgboost`) | Fast | High | Low | Large datasets, speed |
| SVM (`svm`) | Slow | High | High | Small datasets, accuracy |
| LightGBM (`lightgbm`) | Very Fast | High | Low | Very large datasets |

**Recommendation:** Start with Random Forest (default), then try XGBoost if you need better speed.

## Memory and Performance

**Memory allocation:**
- `MEMSIZE = 8`: For 8GB RAM systems
- `MEMSIZE = 16`: For 16GB+ RAM systems
- Increase if you get "out of memory" errors

**CPU cores:**
- `MULTICORES = 4`: For 4+ core systems
- Set to `parallel::detectCores() - 1` to use all but one core

**Processing time estimates:**
- Training: 5-30 minutes (depends on # samples and algorithm)
- Classification: 10-60 minutes per tile (depends on tile size and # cores)

## Troubleshooting

**"No zip files found"**
- Check that input directory contains `.zip` files
- Verify the path is correct

**"No 8-band SR files found"**
- Check that ZIP files contain `_SR_8b_*.tif` files
- May need to adjust the pattern in `process_planetscope.R`

**"Training samples file not found"**
- Create training samples first (see Step 2)
- Verify the path in `classify_planetscope.R`

**"parse_info doesn't match filename"**
- Check the output of `process_planetscope.R`
- Filename structure may have changed
- Adjust `parse_info` in the cube creation code

**Low accuracy**
- Collect more training samples (100+ per class recommended)
- Check that samples are correctly labeled
- Try different classification algorithms
- Verify samples are pure (not mixed pixels)

## References

- [sits documentation](https://e-sensing.github.io/sitsbook/)
- [PlanetScope data specs](https://developers.planet.com/docs/data/planetscope/)
- [GDAL documentation](https://gdal.org/)

## Contact

For issues or questions, consult the sits documentation or create an issue on the sits GitHub repository.
