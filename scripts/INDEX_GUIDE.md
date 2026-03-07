# Spectral Indices Guide for Land Cover Classification

This guide explains how spectral indices help distinguish between your 10 land cover classes using PlanetScope 8-band imagery.

## Your Classification Classes

1. **Paddy** (rice fields)
2. **Water** (water bodies)
3. **Settlement** (urban/built-up)
4. **Bareland** (bare soil)
5. **Natural forest** (primary forest)
6. **Production forest** (timber plantations)
7. **Agroforest** (mixed tree-crop systems)
8. **Ladang** (shifting cultivation)
9. **Sparse vegetation**
10. **Grassland**

---

## Why Use Indices?

**Problem with raw bands alone:**
- Many classes have similar reflectance values in individual bands
- Natural forest vs Production forest: Both are green/dense
- Paddy vs Grassland: Both have vegetation
- Bareland vs Settlement: Both have low vegetation

**Solution with indices:**
- Indices combine bands to emphasize specific features
- **NDVI** reveals vegetation vigor differences
- **NDWI** distinguishes water content (paddy vs grassland)
- **NDRE** separates forest types by chlorophyll
- **BSI** identifies bare soil patterns
- **Temporal patterns** in indices capture phenology (ladang cycles)

---

## Index Descriptions

### Vegetation Indices

#### NDVI - Normalized Difference Vegetation Index
**Formula:** `(NIR - Red) / (NIR + Red)`
**Range:** -1 to 1 (higher = more/healthier vegetation)
**Best for:** Overall vegetation amount and health

**Class discrimination:**
- **Forest** (0.7-0.9): Very high, stable
- **Paddy** (0.3-0.8): Cycles from low to high
- **Grassland** (0.4-0.7): Moderate, seasonal
- **Sparse vegetation** (0.2-0.4): Low
- **Bareland** (<0.2): Very low

#### EVI - Enhanced Vegetation Index
**Formula:** `2.5 * (NIR - Red) / (NIR + 6*Red - 7.5*Blue + 1)`
**Range:** -1 to 1
**Best for:** Dense vegetation (forests), reduces saturation in high biomass

**Why it helps:**
- **Natural forest**: High EVI, no saturation
- **Production forest**: High EVI, more variability
- **Agroforest**: Moderate EVI with mixed patterns

#### SAVI - Soil Adjusted Vegetation Index
**Formula:** `((NIR - Red) / (NIR + Red + 0.5)) * 1.5`
**Range:** -1 to 1
**Best for:** Areas with visible soil (sparse vegetation, early crop growth)

**Why it helps:**
- Reduces soil background interference
- **Ladang** (bare phase): More accurate than NDVI
- **Sparse vegetation**: Better discrimination
- **Paddy** (early growth): Separates from bareland

#### NDRE - Normalized Difference Red Edge
**Formula:** `(NIR - RedEdge) / (NIR + RedEdge)`
**Range:** -1 to 1
**Best for:** Chlorophyll content, forest type discrimination

**Class discrimination:**
- **Natural forest**: Higher NDRE (mature, diverse canopy)
- **Production forest**: Lower NDRE (monoculture, younger)
- **Agroforest**: Intermediate, variable

#### GNDVI - Green NDVI
**Formula:** `(NIR - Green) / (NIR + Green)`
**Range:** -1 to 1
**Best for:** Chlorophyll content, grassland detection

**Why it helps:**
- **Grassland** vs **Forest**: Different green reflectance patterns
- Sensitive to grass phenology

#### GCI - Green Chlorophyll Index
**Formula:** `(NIR / Green) - 1`
**Range:** 0 to ~5
**Best for:** Photosynthetic activity

**Class discrimination:**
- **Production forest**: Higher GCI (young, active growth)
- **Natural forest**: Moderate GCI (mature canopy)
- **Grassland**: Variable with season

---

### Water Indices

#### NDWI - Normalized Difference Water Index
**Formula:** `(Green - NIR) / (Green + NIR)`
**Range:** -1 to 1 (higher = more water)
**Best for:** Water detection, moisture content

**Class discrimination:**
- **Water**: Very high (>0.3)
- **Paddy** (flooded): High (0.2-0.5) during flooding
- **Paddy** (drained): Low (<0)
- **Forest**: Very low (<-0.2)

#### MNDWI - Modified NDWI
**Formula:** `(GreenI - NIR) / (GreenI + NIR)`
**Range:** -1 to 1
**Best for:** Enhanced water detection, separates from built-up

**Why it helps:**
- Better discrimination of **Water** from **Settlement**
- Detects flooded **Paddy** more reliably

#### LSWI - Land Surface Water Index
**Formula:** `(NIR - RedEdge) / (NIR + RedEdge)`
**Range:** -1 to 1
**Best for:** Soil/vegetation moisture

**Why it helps:**
- **Paddy** moisture patterns over time
- Wet season vs dry season in **Ladang**

---

### Soil/Bareland Indices

#### BSI - Bare Soil Index
**Formula:** `((Red + Green) - (NIR + Blue)) / ((Red + Green) + (NIR + Blue))`
**Range:** -1 to 1 (higher = more bare soil)
**Best for:** Bareland detection

**Class discrimination:**
- **Bareland**: High (>0.1)
- **Settlement**: Moderate (concrete/asphalt)
- **Ladang** (bare phase): High, temporary
- **Sparse vegetation**: Moderate
- **Forest**: Very low (<-0.1)

#### BI - Brightness Index
**Formula:** `sqrt((Red² + Green²) / 2)`
**Range:** 0 to ~1
**Best for:** Distinguishing bare soil brightness

**Why it helps:**
- Different soil types have different brightness
- **Bareland** vs **Sparse vegetation**

#### NDTI - Normalized Difference Tillage Index
**Formula:** `(Red - Green) / (Red + Green)`
**Range:** -1 to 1
**Best for:** Recently tilled soil (agricultural)

**Class discrimination:**
- **Ladang** (freshly cleared): High
- **Bareland**: Moderate
- **Settlement**: Variable

---

### Urban/Built-up Indices

#### UI - Urban Index
**Formula:** `(Red - NIR) / (Red + NIR)`
**Range:** -1 to 1 (higher = more built-up)
**Best for:** Settlement detection

**Why it helps:**
- **Settlement**: Positive values (buildings reflect more red than NIR)
- **Vegetation**: Negative values (NIR > Red)
- **Bareland**: Near zero

#### BAEI - Built-up Area Extraction Index
**Formula:** `(Red + 0.3) / (Green + NIR)`
**Range:** ~0 to 2
**Best for:** Separating built-up from natural features

**Class discrimination:**
- **Settlement**: Higher values
- **Bareland**: Lower values than settlement
- **Vegetation**: Very low values

#### VIBI - Visible Built-up Index
**Formula:** `(Red - Blue) / (Red + Blue)`
**Range:** -1 to 1
**Best for:** Urban detection using visible bands only

**Why it helps:**
- **Settlement**: Buildings have specific blue-red relationship
- Complements other urban indices

---

## Class-Specific Index Strategies

### 1. Paddy (Rice Fields)

**Key temporal pattern:** Flooded → Growing → Mature → Harvest → Bare

**Best indices:**
1. **NDVI**: Tracks vegetation growth cycle (0.2 → 0.8 → 0.2)
2. **NDWI**: Detects flooding phase (high when flooded)
3. **LSWI**: Soil moisture throughout cycle
4. **SAVI**: Early growth with soil background
5. **EVI**: Peak vegetation without saturation

**Temporal signature:**
```
Flooding:  NDWI↑↑, NDVI↓
Growing:   NDWI↓, NDVI↑, SAVI↑
Mature:    NDVI↑↑, EVI↑↑
Harvest:   NDVI↓↓, BSI↑
```

**Distinguishes from:**
- **Grassland**: No flooding phase, different NDWI pattern
- **Ladang**: Different cycle timing and duration
- **Water**: NDVI increases after flooding (water stays low)

---

### 2. Water

**Key feature:** Consistently low vegetation, high water content

**Best indices:**
1. **NDWI**: Very high values (>0.3)
2. **MNDWI**: Even higher for water
3. **NDVI**: Very low (<0)

**Temporal signature:**
```
All seasons: NDWI↑↑, MNDWI↑↑, NDVI↓↓ (stable)
```

**Distinguishes from:**
- **Paddy**: NDVI increases during growing season
- **Settlement**: Different spectral signature
- **Bareland**: Lower NDWI

---

### 3. Settlement (Urban/Built-up)

**Key feature:** Low vegetation, spectral signature of concrete/asphalt/roofs

**Best indices:**
1. **UI**: Positive values (red > NIR)
2. **BAEI**: High values
3. **VIBI**: Characteristic pattern
4. **NDVI**: Consistently low

**Temporal signature:**
```
All seasons: UI↑, BAEI↑, NDVI↓ (very stable - no seasonality)
```

**Distinguishes from:**
- **Bareland**: UI and BAEI patterns differ
- **Sparse vegetation**: Settlement has no green-up periods
- **Water**: NDWI patterns differ

---

### 4. Bareland

**Key feature:** No vegetation, exposed soil

**Best indices:**
1. **BSI**: High values
2. **NDVI**: Very low (<0.2)
3. **NDTI**: Variable by soil type
4. **BI**: High brightness

**Temporal signature:**
```
All seasons: BSI↑, NDVI↓ (stable unless temporary)
```

**Distinguishes from:**
- **Settlement**: BSI and BI patterns differ
- **Sparse vegetation**: Bareland has no NDVI peaks
- **Ladang bare phase**: Ladang shows temporal cycle

---

### 5. Natural Forest

**Key feature:** High, stable vegetation; mature, diverse canopy

**Best indices:**
1. **NDVI**: Very high (0.7-0.9)
2. **EVI**: High, prevents saturation
3. **NDRE**: High (mature canopy)
4. **CIre**: High chlorophyll
5. **GNDVI**: Stable high values

**Temporal signature:**
```
All seasons: NDVI↑↑, EVI↑↑, NDRE↑ (very stable)
Minimal seasonality
```

**Distinguishes from:**
- **Production forest**: Higher NDRE, more stable
- **Agroforest**: Higher NDVI, less variability
- **Grassland**: Much higher vegetation indices

---

### 6. Production Forest (Plantations)

**Key feature:** High vegetation, but more uniform/younger than natural forest

**Best indices:**
1. **NDVI**: High (0.6-0.8)
2. **EVI**: High
3. **NDRE**: Lower than natural forest
4. **GCI**: Higher (young, active growth)
5. **SAVI**: Some variability

**Temporal signature:**
```
All seasons: NDVI↑, EVI↑, NDRE moderate
Some seasonality depending on species
```

**Distinguishes from:**
- **Natural forest**: Lower NDRE, different texture
- **Agroforest**: More uniform, higher NDVI
- **Grassland**: Much higher indices

---

### 7. Agroforest

**Key feature:** Mixed trees and crops, intermediate characteristics

**Best indices:**
1. **NDVI**: Moderate-high (0.5-0.7)
2. **NDRE**: Variable (mixed canopy)
3. **SAVI**: Shows understory
4. **GCI**: Variable

**Temporal signature:**
```
NDVI moderate, more variable than forest
NDRE shows mixed patterns
Some seasonality from crop component
```

**Distinguishes from:**
- **Natural forest**: Lower NDVI, more variability
- **Production forest**: Lower NDVI, mixed patterns
- **Ladang**: Higher baseline NDVI, different cycle

---

### 8. Ladang (Shifting Cultivation)

**Key feature:** Strong cyclical pattern (clear → plant → grow → harvest → fallow)

**Best indices:**
1. **NDVI**: Strong cycles (0.1 → 0.7 → 0.1)
2. **SAVI**: Tracks early growth accurately
3. **NDTI**: High when freshly cleared
4. **EVI**: Peak vegetation phase
5. **BSI**: High during bare phases

**Temporal signature:**
```
Clearing:  BSI↑, NDTI↑, NDVI↓
Planting:  SAVI↑, NDVI starts ↑
Growing:   NDVI↑↑, EVI↑
Harvest:   NDVI↓↓
Fallow:    NDVI gradual ↑, sparse veg
```

**Distinguishes from:**
- **Paddy**: Different cycle timing, no flooding signal
- **Bareland**: Ladang shows vegetation cycles
- **Sparse vegetation**: Ladang has clear temporal pattern

---

### 9. Sparse Vegetation

**Key feature:** Low-moderate vegetation cover, soil visible

**Best indices:**
1. **SAVI**: Better than NDVI with soil background
2. **NDVI**: Low-moderate (0.2-0.4)
3. **GNDVI**: Low
4. **BSI**: Moderate (some soil visible)

**Temporal signature:**
```
SAVI and NDVI low-moderate
Some seasonality but always sparse
BSI moderate (soil always partially visible)
```

**Distinguishes from:**
- **Grassland**: Lower NDVI, higher BSI
- **Bareland**: Some vegetation signal
- **Ladang**: No strong cyclical pattern

---

### 10. Grassland

**Key feature:** Moderate vegetation, seasonal patterns, grass spectral signature

**Best indices:**
1. **NDVI**: Moderate (0.4-0.7)
2. **GNDVI**: Characteristic grass pattern
3. **SAVI**: Moderate
4. **GCI**: Moderate, seasonal

**Temporal signature:**
```
Wet season:  NDVI↑, GNDVI↑
Dry season:  NDVI↓, GNDVI↓
Regular seasonal cycle
```

**Distinguishes from:**
- **Forest**: Much lower NDVI
- **Sparse vegetation**: Higher NDVI
- **Paddy**: No flooding signal, different GNDVI pattern
- **Ladang**: More regular seasonal pattern

---

## Configuration Recommendations

### Option 1: Use All Indices (Recommended for initial testing)
```r
USE_INDICES <- TRUE
INDICES <- "all"
```

**Pros:**
- Maximum discrimination power
- Algorithm selects most important features
- Best for complex classification (10 classes)

**Cons:**
- Slower processing
- More storage
- Potential redundancy

---

### Option 2: Selective Indices (Optimized)
```r
USE_INDICES <- TRUE
INDICES <- c("vegetation", "water", "soil")  # Skip urban if not needed
```

**Pros:**
- Faster than "all"
- Still comprehensive
- Good balance

---

### Option 3: Class-Specific Minimal Set

If you want to minimize indices while maximizing discrimination:

```r
# In calculate_indices.R, calculate only these:
# - NDVI (all classes)
# - EVI (forests, paddy, ladang)
# - NDWI (water, paddy)
# - NDRE (forest types)
# - SAVI (sparse veg, ladang, paddy)
# - BSI (bareland, ladang)
# - UI (settlement)
```

---

## Tips for Success

1. **Start with all indices** - Let the algorithm learn which are most important
2. **Check feature importance** after training - See which indices the model uses most
3. **Temporal patterns are key** - The *change* in indices over time is often more important than absolute values
4. **Combine with dates** - Use start_date/end_date in training samples to capture correct phenological states
5. **Validate with field data** - Ground truth helps verify that indices are separating classes correctly

---

## Expected Processing Time

With all indices enabled:
- **Index calculation**: +10-20 minutes per tile
- **Training**: ~Same (indices don't significantly affect training time)
- **Classification**: +30-50% longer than without indices
- **Total pipeline**: Expect 2-3x longer than bands-only

**Worth it?** Yes! The accuracy improvement typically justifies the extra time.

---

## Troubleshooting

**Problem**: Classes still confusing (e.g., Natural forest vs Production forest)
**Solution**: Check if samples have proper temporal coverage and dates. Add more samples for confused classes.

**Problem**: Processing too slow
**Solution**: Use selective indices or increase MEMSIZE and MULTICORES in classify_planetscope.R

**Problem**: Running out of memory
**Solution**:
1. Reduce number of indices
2. Process tiles individually
3. Increase swap space or use a machine with more RAM

---

## Next Steps

1. Review which classes are most difficult to separate
2. Select appropriate indices (start with "all")
3. Collect training samples with proper dates
4. Run classification
5. Review confusion matrix to see which classes are mixed
6. Refine samples or indices based on results
