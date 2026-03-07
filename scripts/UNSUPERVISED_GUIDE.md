# Unsupervised Classification for Sample Selection

Use unsupervised classification (clustering) to explore your data and identify good locations for collecting training samples.

## Why Do This First?

**Problem:** Without prior knowledge, where do you place training samples?

**Solution:** Unsupervised clustering reveals natural patterns in your data:
- Identifies areas with similar spectral/temporal characteristics
- Shows you the diversity of patterns in your study area
- Suggests strategic locations for sampling
- Helps ensure you capture all land cover types

## Two Approaches Available

### Approach 1: K-means Clustering (Recommended for beginners)

**Script:** `unsupervised_clustering.R`

**How it works:**
1. Calculates temporal statistics (mean, std, min, max) for all bands/indices
2. Groups pixels with similar statistics into K clusters
3. Suggests likely land cover type for each cluster
4. Extracts sample points from each cluster

**Best for:**
- Quick exploration
- Understanding spectral patterns
- Clear separation based on index values

**Advantages:**
- Fast
- Interpretable (shows mean NDVI, NDWI, etc. for each cluster)
- Suggests land cover types automatically
- Good for stable land covers

**Run it:**
```bash
Rscript scripts/unsupervised_clustering.R
```

**Configuration:**
- `N_CLUSTERS`: Number of clusters (start with 10 for your 10 classes)
- `SAMPLE_SIZE`: Pixels to sample (5000 = faster, 20000 = more accurate)
- `POINTS_PER_CLUSTER`: Sample points per cluster (20 recommended)

---

### Approach 2: Self-Organizing Maps (SOM)

**Script:** `explore_with_som.R`

**How it works:**
1. Uses full time series (not just statistics)
2. Creates a 2D grid of neurons that learn temporal patterns
3. Maps each pixel to nearest neuron
4. Extracts representative points from each neuron

**Best for:**
- Temporal pattern analysis
- Capturing phenological cycles
- Finding unique temporal signatures

**Advantages:**
- Preserves temporal information
- Better for classes with characteristic cycles (paddy, ladang)
- Neurons organized spatially (similar neurons are neighbors)
- Excellent for exploratory analysis

**Run it:**
```bash
Rscript scripts/explore_with_som.R
```

**Configuration:**
- `SOM_GRID_X`, `SOM_GRID_Y`: Grid size (5×5 = 25 neurons)
- `SAMPLE_SIZE`: Pixels to sample (2000 recommended)
- `POINTS_PER_NEURON`: Points per neuron (5 recommended)

---

## Comparison

| Feature | K-means | SOM |
|---------|---------|-----|
| **Speed** | Fast | Medium |
| **Uses temporal patterns** | Via statistics | Full time series |
| **Interpretability** | High (shows mean values) | Medium (pattern-based) |
| **Best for** | Spectral separation | Temporal separation |
| **Output** | Cluster labels + suggestions | Neuron patterns |
| **Number of groups** | Fixed (you set K) | Fixed (grid size) |

---

## Workflow Comparison

### K-means Workflow

1. **Run clustering:**
   ```bash
   Rscript scripts/unsupervised_clustering.R
   ```

2. **Review cluster characteristics:**
   ```
   Cluster    NDVI_mean    NDWI_mean    NDRE_mean    BSI_mean
   C1         0.850        -0.200       0.350        -0.150  → natural_forest
   C2         0.750        -0.180       0.250        -0.100  → production_forest
   C3         0.450        0.150        0.100        0.000   → paddy/grassland
   C4         0.100        -0.050       0.050        0.200   → bareland
   ...
   ```

3. **Open suggested points in QGIS:**
   - File: `data/clustering_results/suggested_sample_points.gpkg`
   - Field `suggested_label` shows automated guess
   - Verify with imagery and update `label` field

4. **Refine samples:**
   - Keep good samples
   - Delete ambiguous ones
   - Add more if needed

---

### SOM Workflow

1. **Run SOM:**
   ```bash
   Rscript scripts/explore_with_som.R
   ```

2. **Review neuron distribution:**
   ```
   Neuron 1_1: 150 pixels
   Neuron 1_2: 120 pixels
   Neuron 2_1: 200 pixels
   ...
   ```

3. **Open sample points in QGIS:**
   - File: `data/som_results/som_sample_points.gpkg`
   - Field `neuron` groups similar temporal patterns
   - Review imagery for each neuron group

4. **Identify patterns:**
   - Points with same neuron = similar temporal behavior
   - Determine what land cover they represent
   - Update `label` field

---

## Recommendations by Use Case

### For Your 10 Classes

**If classes differ mainly by spectral characteristics:**
→ Use **K-means**
- Settlement vs Forest (different NDVI)
- Water vs Bareland (different NDWI/BSI)
- Natural vs Production forest (different NDRE)

**If classes differ by temporal patterns:**
→ Use **SOM**
- Paddy (flooding cycles)
- Ladang (clearing cycles)
- Seasonal crops vs stable vegetation

**Best approach:**
→ Run **BOTH**, compare results!
- K-means finds spectral clusters
- SOM finds temporal clusters
- Together they give complete picture

---

## Expected Outputs

### K-means Outputs

**Files created:**
- `data/clustering_results/suggested_sample_points.csv`
- `data/clustering_results/suggested_sample_points.gpkg`

**CSV format:**
```csv
cluster,longitude,latitude,suggested_label,label,start_date,end_date
1,-47.123,10.456,natural_forest,,,
1,-47.124,10.457,natural_forest,,,
2,-47.125,10.458,paddy/grassland,,,
3,-47.126,10.459,bareland,,,
...
```

**What to do:**
1. Open `.gpkg` in QGIS
2. Load PlanetScope imagery as background
3. For each point:
   - Verify `suggested_label` is correct
   - Update `label` field with actual land cover
   - Add `start_date` and `end_date` (YYYY-MM-DD)
   - Delete point if unclear
4. Export as `training_samples.gpkg`

---

### SOM Outputs

**Files created:**
- `data/som_results/som_sample_points.csv`
- `data/som_results/som_sample_points.gpkg`

**CSV format:**
```csv
neuron,longitude,latitude,label,start_date,end_date
1_1,-47.123,10.456,,,
1_1,-47.124,10.457,,,
1_2,-47.125,10.458,,,
2_1,-47.126,10.459,,,
...
```

**What to do:**
1. Open `.gpkg` in QGIS
2. Filter by neuron (all points with same neuron have similar patterns)
3. Identify what land cover each neuron represents
4. Update `label`, `start_date`, `end_date` fields
5. Export as `training_samples.gpkg`

---

## Configuration Tips

### Number of Clusters/Neurons

**Too few (< 10):**
- Misses subtle differences
- Lumps different classes together
- Example: C1 = "all forests" (no separation)

**Too many (> 20):**
- Over-segments data
- Multiple clusters per class
- Example: C1 = "dense forest", C2 = "medium forest", C3 = "sparse forest"

**Recommended:**
- Start with N_CLUSTERS = 10 (one per class)
- Or N_CLUSTERS = 15 (allows for within-class variation)
- For SOM: 5×5 grid (25 neurons) gives good detail

### Sample Size

**Small (< 1000):**
- Very fast
- May miss rare patterns
- OK for quick exploration

**Medium (2000-5000):**
- Good balance
- Captures most patterns
- Recommended for initial run

**Large (> 10000):**
- Slower but more comprehensive
- Better representation
- Use for final sample selection

---

## Interpreting Results

### K-means Cluster Characteristics

**Example cluster:**
```
Cluster 5:
  NDVI_mean: 0.45
  NDVI_std: 0.20  (high = variable)
  NDWI_mean: 0.05
  BSI_max: 0.25
  Suggestion: ladang
```

**Interpretation:**
- Moderate NDVI (0.45) = sometimes vegetated
- High NDVI_std (0.20) = temporal cycles
- Low NDWI = no flooding
- High BSI peaks = bare soil phases
- **Conclusion:** Likely shifting cultivation (ladang)

---

### SOM Neuron Patterns

**Example:**
```
Neuron 3_4: 180 pixels
Points at:
  - (-47.123, 10.456)
  - (-47.234, 10.567)
  - (-47.345, 10.678)
```

**What to do:**
1. View all 3 points in QGIS
2. Check PlanetScope imagery
3. If all 3 are rice paddies → label entire neuron as "paddy"
4. If mixed → investigate further or split manually

---

## Common Issues and Solutions

### Issue: All points in one cluster

**Cause:** Not enough variation in sampled pixels

**Solution:**
- Increase `SAMPLE_SIZE`
- Check that imagery covers diverse area
- Verify indices calculated correctly

---

### Issue: Suggested labels don't make sense

**Cause:** Automated suggestions are heuristic-based

**Solution:**
- Use suggestions as GUIDE only
- Always verify with imagery
- Field knowledge is more important!

---

### Issue: Missing important land cover types

**Cause:** Rare classes don't appear in random sample

**Solution:**
- Increase `SAMPLE_SIZE`
- After initial clustering, manually add samples for missing classes
- Use `POINTS_PER_CLUSTER` to get more points

---

### Issue: Too many points to verify

**Cause:** High `POINTS_PER_CLUSTER` × many clusters

**Solution:**
- Reduce `POINTS_PER_CLUSTER` to 10 or fewer
- Focus on clusters with distinct characteristics
- Delete redundant points from similar clusters

---

## After Unsupervised Analysis

### Next Steps

1. **Refine sample points:**
   ```
   # In QGIS:
   - Load suggested_sample_points.gpkg
   - Load PlanetScope imagery
   - Verify and update labels
   - Add dates
   - Save as training_samples.gpkg
   ```

2. **Check sample quality:**
   ```r
   source("scripts/prepare_training_samples.R")
   validate_training_samples("data/training_samples.gpkg")
   ```

3. **Run supervised classification:**
   ```bash
   Rscript scripts/classify_planetscope.R
   ```

4. **Evaluate results:**
   - Review accuracy metrics
   - Check confusion matrix
   - Identify confused classes
   - Collect more samples if needed

---

## Tips for Success

1. **Don't trust clusters blindly**
   - Clusters show patterns, not ground truth
   - Always verify with imagery or field data

2. **Use multiple dates in verification**
   - Check if point is stable or changing
   - Set start_date and end_date accordingly

3. **Balance your samples**
   - Aim for similar number of points per class
   - Rare classes may need manual addition

4. **Iterate**
   - Run clustering → collect samples → classify → refine
   - Use classification results to identify areas needing more samples

5. **Combine approaches**
   - Run K-means for spectral patterns
   - Run SOM for temporal patterns
   - Merge sample points from both

---

## Example: Complete Workflow

```bash
# 1. Run unsupervised clustering
Rscript scripts/unsupervised_clustering.R

# 2. Review results
# Opens: data/clustering_results/suggested_sample_points.gpkg in QGIS
# Update labels, dates, save as training_samples.gpkg

# 3. Validate samples
R -e "source('scripts/prepare_training_samples.R'); validate_training_samples('data/training_samples.gpkg')"

# 4. Run supervised classification
Rscript scripts/classify_planetscope.R

# 5. Review accuracy, iterate as needed
```

---

## Quick Reference

| Goal | Use This | Command |
|------|----------|---------|
| Quick spectral exploration | K-means | `Rscript scripts/unsupervised_clustering.R` |
| Temporal pattern discovery | SOM | `Rscript scripts/explore_with_som.R` |
| Both spectral and temporal | Both scripts | Run both, merge results |
| Fast test run | K-means, small sample | Set `SAMPLE_SIZE=1000` |
| Comprehensive analysis | K-means, large sample | Set `SAMPLE_SIZE=10000` |

---

## Summary

Unsupervised classification is a powerful tool for:
- **Exploring** your data before supervised classification
- **Identifying** sampling locations strategically
- **Understanding** natural patterns in imagery
- **Ensuring** comprehensive class coverage

Use it as a **starting point**, not the final answer. Always verify with imagery and field knowledge!
