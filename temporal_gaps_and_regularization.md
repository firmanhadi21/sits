# Temporal Gaps and Regularization in Time Series Analysis

## Understanding sits_regularize() and When to Use It

### What is `sits_regularize()`?

`sits_regularize()` resamples your irregular time series to a **regular temporal grid** (e.g., every 16 days). It:
- Interpolates values for dates with missing/cloudy data
- Creates uniform time steps across all pixels
- Is **required** by `sits_get_data()` for extracting pixel time series
- Is needed by some machine learning models that expect consistent temporal intervals

### Current PlanetScope Cube Status

The cloud-masked cube has **irregular temporal spacing**:
- 19 dates spanning Jan 2023 - Nov 2025
- Gaps ranging from 15 to 205 days (mean: 58 days)
- Different cloud coverage per date (71-98% cloud-free)

### Why Regularization is NOT Needed for This Workflow

The classification workflow can skip regularization because:

1. **Pre-calculated indices exist** - Each date already has complete NDVI, NDWI, NDRE, etc. images

2. **sits_classify() works with irregular cubes** - When you run:
   ```r
   model <- sits_train(samples, sits_rfor())
   classified <- sits_classify(cube, model)
   ```
   It will use the **actual dates available** (19 dates), not interpolated values

3. **Avoids artificial data** - Regularization would interpolate between observations, potentially creating artifacts. This approach uses only real, observed values.

4. **Cloud masking already handled** - Cloud-masked data has NA for cloudy pixels. Classification will work with available cloud-free observations per pixel.

## What Happens During Regularization with Big Gaps?

### Your Temporal Gaps

From the visualization analysis:
- **Minimum gap:** 15 days (fine)
- **Maximum gap:** 205 days (~7 months!)
- **Mean gap:** 58 days
- **Median gap:** 38.5 days

### Example: The 205-Day Gap Problem

Consider this scenario in your data:
- **Image A:** July 14, 2024 (NDVI = 0.75, healthy vegetation)
- **[205-day gap with NO data]**
- **Image B:** January 10, 2025 (NDVI = 0.35, stressed/harvested vegetation)

If you run `sits_regularize()` with a 16-day interval, it would create **~13 interpolated dates**:

```
Jul 14: NDVI = 0.75 [observed]
Jul 30: NDVI = 0.72 [interpolated]
Aug 15: NDVI = 0.68 [interpolated]
Aug 31: NDVI = 0.65 [interpolated]
Sep 16: NDVI = 0.61 [interpolated]
Oct 02: NDVI = 0.58 [interpolated]
Oct 18: NDVI = 0.54 [interpolated]
Nov 03: NDVI = 0.51 [interpolated]
Nov 19: NDVI = 0.47 [interpolated]
Dec 05: NDVI = 0.43 [interpolated]
Dec 21: NDVI = 0.40 [interpolated]
Jan 06: NDVI = 0.36 [interpolated]
Jan 10: NDVI = 0.35 [observed]
```

## Problems with Interpolation Across Large Gaps

### 1. Linear Interpolation Assumes Smooth Change

- **Reality:** Dam construction might cause **abrupt change** (forest cleared in September)
- **Interpolation:** Shows gradual, linear decline
- **Result:** **Masks the actual timing and nature of change**

### 2. Missing Critical Events

What if during that 205-day gap:
- Forest was cleared (September)
- Site was bareland (October-November)
- Construction started (December)

The interpolation would **completely miss** these phases, showing only a smooth transition.

### 3. False Seasonal Patterns

The interpolated decline might look like natural senescence when it's actually human disturbance.

### 4. Statistical Artifacts

- Variance calculations include fake interpolated values
- Trend analysis is biased by assumption of linear change
- Anomaly detection might miss the real disturbance

## Visual Comparison

### Without Regularization (Current Approach)

```
NDVI
0.8 |     *
0.7 |
0.6 |
0.5 |
0.4 |                                          *
0.3 |____________________________________________
    Jan  Mar  May  Jul  Sep  Nov  Jan  Mar
         2024                    2025
```

Clear 205-day gap - you know there's no data.

### With Regularization (Interpolated)

```
NDVI
0.8 |     *
0.7 |        *
0.6 |           *  *
0.5 |                 *  *
0.4 |                       *  *  *  *       *
0.3 |____________________________________________
    Jan  Mar  May  Jul  Sep  Nov  Jan  Mar
         2024                    2025
```

Looks like smooth decline - **misleading!**

## Recommended Approaches for Dam Monitoring

### Best Approach: Use Irregular Time Series As-Is

#### 1. Plot Irregular Time Series with Visible Gaps

```r
# Plot with gaps visible
ggplot(timeseries, aes(x = date, y = ndvi)) +
  geom_point(size = 3) +
  geom_line() +  # Lines will show gaps
  labs(title = "NDVI - Actual Observations Only")
```

#### 2. Analyze Change Between Specific Date Pairs

```r
# Compare specific dates
ndvi_2023 <- rast("data/planetscope_indices_masked/NDVI/20230731_NDVI.tif")
ndvi_2024 <- rast("data/planetscope_indices_masked/NDVI/20240714_NDVI.tif")
change <- ndvi_2024 - ndvi_2023

# Visualize change
plot(change, main = "NDVI Change 2023-2024")
```

#### 3. Use Temporal Statistics (Already Created)

```r
# Load temporal statistics
ndvi_std <- rast("data/planetscope_index_stats_masked/NDVI_std.tif")
ndvi_max <- rast("data/planetscope_index_stats_masked/NDVI_max.tif")
ndvi_min <- rast("data/planetscope_index_stats_masked/NDVI_min.tif")

# High std = areas with change (including dam construction)
# No interpolation needed!
plot(ndvi_std, main = "NDVI Variability (Std Dev)")
```

#### 4. Classification with Irregular Cube

```r
# Works perfectly with your 19 irregular dates
model <- sits_train(samples, sits_rfor())
classified <- sits_classify(cube, model)
```

### If You Really Need Regular Time Series

#### Option 1: Regularize with Caution

```r
# Use larger interval to reduce interpolation
regular_cube <- sits_regularize(cube, period = "P2M")  # Every 2 months
# This creates fewer interpolated points
```

**Pros:**
- Fewer interpolated values (3-4 instead of 13)
- Less assumption about intermediate states

**Cons:**
- Still interpolates across gaps
- May still miss rapid changes

#### Option 2: Seasonal Composites

```r
# Create seasonal composites instead of regular intervals
# Example: Dry season 2023, Wet season 2023-24, Dry season 2024, etc.

# Dry season composite (June-September)
dry_2023 <- median(c(ndvi_20230626, ndvi_20230731, ndvi_20230823, ndvi_20230926))
dry_2024 <- median(c(ndvi_20240714, ndvi_20240805, ndvi_20240916))

# Compare dry seasons
change_dry <- dry_2024 - dry_2023
```

#### Option 3: Acknowledge Gaps in Analysis

```r
# Filter out large gaps before analysis
max_gap_days <- 60

timeline <- sits_timeline(cube)
gaps <- diff(as.Date(timeline))

# Identify problematic gaps
large_gaps <- which(gaps > max_gap_days)
cat("Warning: Large gaps at positions:", large_gaps, "\n")
cat("Gap sizes:", gaps[large_gaps], "days\n")
```

## Why NOT to Regularize for This Project

Your current approach is actually **better** for dam construction monitoring:

| Aspect | Irregular Cube (Current) | Regularized Cube |
|--------|-------------------------|------------------|
| Data authenticity | ✓ Real observations only | ✗ Artificial interpolated values |
| Change detection | ✓ Clear before/after comparison | ✗ Smoothed transitions hide abrupt changes |
| Temporal statistics | ✓ Already computed, handles gaps naturally | ✗ Stats polluted by fake data |
| Classification | ✓ Works with irregular cubes | ✓ Also works, but unnecessary |
| Gap awareness | ✓ You can see exactly when you have/don't have data | ✗ Gaps hidden by interpolation |
| Dam construction | ✓ Abrupt changes preserved | ✗ Gradual transitions mask reality |

## Key Takeaway

**The 205-day gap is valuable information** - it tells you there's a data-poor period you should be cautious about interpreting.

For dam construction monitoring where:
- Changes are **abrupt** (forest → cleared → construction)
- Timing matters (when did clearing happen?)
- You need to identify specific change events

**Don't regularize.** Use:
1. Temporal statistics (NDVI_std shows changed areas)
2. Date-specific comparisons (NDVI_2023 vs NDVI_2024)
3. Direct classification on irregular cube (sits handles this)

## When Regularization WOULD Be Appropriate

Regularization is useful when:
- You need to compare with other satellite data at fixed intervals (e.g., Landsat every 16 days)
- Your gaps are small (< 30 days) and changes are gradual
- You're modeling seasonal phenology (natural vegetation cycles)
- You need to fill small gaps from cloud cover for visualization
- Your analysis method requires equal temporal spacing

For this dam monitoring project: **None of these apply.**

## Summary

| Use Case | Regularize? | Why |
|----------|-------------|-----|
| Classification with pre-calculated indices | ✗ No | sits_classify() handles irregular cubes |
| Temporal statistics (min/max/std) | ✗ No | Already computed, handles gaps naturally |
| Change detection (forest → construction) | ✗ No | Preserves abrupt changes |
| Time series plotting | ✗ No | Plot irregular series with visible gaps |
| Pixel-level time series extraction | ✓ Yes* | Required by sits_get_data(), but not needed for workflow |
| Comparison with fixed-interval data | ✓ Maybe | Only if integrating with other sensors |

\* Even then, consider if you really need it or if temporal statistics suffice.
