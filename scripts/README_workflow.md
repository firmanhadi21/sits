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
- `USE_INDICES`: Enable spectral indices (TRUE/FALSE)
- `INDICES`: Which index groups to use ("all", or c("vegetation", "water", "soil", "urban"))
- `USE_TEMPORAL_FEATURES`: Add temporal statistics (mean, std, min, max, amplitude)
- `KEEP_TIME_SERIES`: Keep raw time series + stats (TRUE) or stats only (FALSE)
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

**IMPORTANT: Include date information!**

Training samples should include `start_date` and `end_date` columns to specify when each label is valid. This is crucial because:
- Land cover changes over time (e.g., forest → cropland)
- Your label should only apply to the specific time period you observed it
- Without dates, the entire time series will be used, which may include incorrect labels

**Option A: From CSV (RECOMMENDED)**

Create a CSV file with coordinates and dates:
```csv
longitude,latitude,label,start_date,end_date
-47.123,10.456,forest,2023-01-01,2025-12-31
-47.124,10.457,water,2024-01-01,2024-12-31
-47.125,10.458,cropland,2024-07-01,2024-09-30
-47.126,10.459,forest,2024-07-14,2024-07-14
```

**Date guidelines:**
- Use `YYYY-MM-DD` format
- `start_date`: First date when label is valid
- `end_date`: Last date when label is valid
- For single date: use same date for both (or use `date` column instead)
- For stable classes (forest, water): use wide date range covering all imagery
- For seasonal classes (crops): use specific growing season dates

Convert to GeoPackage:
```r
source("scripts/prepare_training_samples.R")

samples <- create_samples_from_csv(
    csv_file = "data/training_points.csv",
    output_file = "data/training_samples.gpkg"
)
```

**Option B: Collect in QGIS**

1. Open QGIS
2. Load one of your PlanetScope images as reference
3. Create a new GeoPackage layer:
   - Layer > Create Layer > New GeoPackage Layer
   - Add fields:
     - `label` (text): Class name
     - `start_date` (date): Start of validity period
     - `end_date` (date): End of validity period
4. Digitize training samples (points or polygons)
5. For each sample, fill in all three fields
6. Save as `data/training_samples.gpkg`

**Validate samples:**
```r
source("scripts/prepare_training_samples.R")

# Validate samples
validate_training_samples("data/training_samples.gpkg")

# Or validate with cube to check spatial/temporal overlap
library(sits)
cube <- sits_cube(
    source = "PLANET",
    collection = "MOSAIC-8B",
    data_dir = "data/planetscope_processed/",
    parse_info = c("date", "X1", "X2", "tile", "X3", "X4", "X5", "X6", "X7", "X8", "band"),
    delim = "_"
)
validate_training_samples("data/training_samples.gpkg", cube = cube)
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
- Must have a `label` column with class names
- **IMPORTANT**: Should have `start_date` and `end_date` columns (YYYY-MM-DD)
- Samples should be spatially distributed across the study area
- Coordinate system must match the imagery

**Why dates matter:**
- Land cover changes over time (deforestation, agriculture cycles, urban expansion)
- Your label is only valid for a specific time period
- Without dates, time series from ALL dates will be used, potentially mixing different land cover states
- This leads to noisy training data and reduced accuracy

**Date strategy examples:**

1. **Stable land cover (forest, water bodies):**
   ```
   label: forest
   start_date: 2023-01-01
   end_date: 2025-12-31
   # Uses entire time series - forest is forest throughout
   ```

2. **Seasonal crops:**
   ```
   label: cropland
   start_date: 2024-06-01
   end_date: 2024-09-30
   # Only uses growing season imagery
   ```

3. **Land cover change:**
   ```
   # Same location, two samples:
   Sample 1: forest, 2023-01-01 to 2023-12-31
   Sample 2: cropland, 2024-01-01 to 2025-12-31
   ```

**Recommended:**
- 100+ samples per class for robust models
- Include samples from different seasons/years if available
- Ensure samples are pure (not mixed classes)
- Balance sample sizes across classes
- Verify dates match actual imagery dates in your cube

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

## Temporal Features vs Raw Time Series

### Understanding How sits Uses Time Series Data

**Option 1: Raw Time Series Only (sits default)**
```r
USE_TEMPORAL_FEATURES <- FALSE
```

- Uses individual values from each date: `[NDVI_2023-01-01, NDVI_2023-05-01, ...]`
- Feature count: 19 dates × 24 bands/indices = **456 features**
- Good: Captures exact temporal patterns
- Challenge: Many features, sensitive to missing dates

**Option 2: Temporal Statistics Only**
```r
USE_TEMPORAL_FEATURES <- TRUE
KEEP_TIME_SERIES <- FALSE
```

- Creates summary features: `NDVI_mean, NDVI_std, NDVI_min, NDVI_max, NDVI_amplitude`
- Feature count: 24 bands/indices × 5 stats = **120 features**
- Good: Robust to irregular sampling, interpretable, faster
- Example: "Natural forest has high stable NDVI" = `NDVI_mean=0.85, NDVI_std=0.05`

**Option 3: Combined Approach (RECOMMENDED)**
```r
USE_TEMPORAL_FEATURES <- TRUE
KEEP_TIME_SERIES <- TRUE
```

- Uses both raw time series AND statistics
- Feature count: **456 + 120 = 576 features**
- ML algorithm selects most informative features
- Best accuracy, handles both patterns and stability

### Temporal Statistics Explained

For each band/index, calculates:

| Statistic | What It Captures | Example Use |
|-----------|-----------------|-------------|
| **mean** | Average value over time | High for forests, low for bareland |
| **std** | Temporal stability | Low for stable classes (forest), high for dynamic (ladang) |
| **min** | Lowest point | Bare phase in ladang, dry season minimum |
| **max** | Highest point | Peak vegetation in growth cycle |
| **amplitude** | Half the range | Temporal variation magnitude |

### Example: Natural Forest vs Ladang

**Natural Forest:**
```
NDVI_mean: 0.85 (high vegetation)
NDVI_std: 0.05 (very stable)
NDVI_min: 0.80 (always high)
NDVI_max: 0.90 (peak is near average)
NDVI_amplitude: 0.05 (minimal variation)
```

**Ladang:**
```
NDVI_mean: 0.45 (moderate - mixed bare and vegetated)
NDVI_std: 0.25 (highly variable)
NDVI_min: 0.10 (bare soil phase)
NDVI_max: 0.80 (peak vegetation)
NDVI_amplitude: 0.35 (large swings)
```

The statistics **clearly differentiate** the two classes!

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
