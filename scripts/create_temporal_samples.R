#!/usr/bin/env Rscript
# Create temporally-aware training samples for land cover change areas
# Useful for dam development, deforestation, urbanization, etc.

suppressPackageStartupMessages({
    library(sf)
    library(sits)
})

cat("========================================\n")
cat("Temporal Training Sample Creator\n")
cat("========================================\n\n")

#' Create temporal training samples from change areas
#'
#' This function helps create training samples where the same location
#' has different land cover labels at different time periods.
#'
#' @param locations data.frame with lon, lat columns
#' @param changes list of change sequences
#' @param output_file path to save GeoPackage
#' @return sf object with temporal samples
#' @export
create_temporal_samples <- function(locations, changes, output_file) {

    all_samples <- list()

    for (i in seq_len(nrow(locations))) {
        lon <- locations$longitude[i]
        lat <- locations$latitude[i]
        area_id <- locations$area_id[i]
        change_type <- locations$change_type[i]

        # Get change sequence for this type
        if (change_type %in% names(changes)) {
            sequence <- changes[[change_type]]

            for (j in seq_len(nrow(sequence))) {
                sample <- data.frame(
                    area_id = area_id,
                    longitude = lon,
                    latitude = lat,
                    label = sequence$label[j],
                    start_date = as.Date(sequence$start_date[j]),
                    end_date = as.Date(sequence$end_date[j]),
                    change_type = change_type,
                    stringsAsFactors = FALSE
                )
                all_samples[[length(all_samples) + 1]] <- sample
            }
        }
    }

    # Combine all samples
    samples_df <- do.call(rbind, all_samples)

    # Convert to sf
    samples_sf <- st_as_sf(
        samples_df,
        coords = c("longitude", "latitude"),
        crs = 4326
    )

    # Save
    st_write(samples_sf, output_file, delete_dsn = TRUE)

    cat("Created", nrow(samples_sf), "temporal samples\n")
    cat("Saved to:", output_file, "\n")

    return(samples_sf)
}

# ==============================================================================
# Example Usage: Dam Development Area
# ==============================================================================

cat("Example: Creating samples for dam development areas\n\n")

# Define change sequences for different transition types
change_sequences <- list(

    # ==========================================================================
    # DAM CONSTRUCTION RELATED CHANGES
    # ==========================================================================

    # Dam construction area: forest -> bareland -> built_up
    dam_construction = data.frame(
        label = c("forest", "bareland", "built_up"),
        start_date = c("2023-01-01", "2024-01-01", "2024-07-01"),
        end_date = c("2023-12-31", "2024-06-30", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # Future reservoir area (not flooded yet): forest -> bareland -> bareland
    reservoir_area_cleared = data.frame(
        label = c("forest", "bareland", "bareland"),
        start_date = c("2023-01-01", "2024-01-01", "2024-06-01"),
        end_date = c("2023-12-31", "2024-05-31", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # Access road construction: forest -> bareland -> built_up
    road_construction = data.frame(
        label = c("forest", "bareland", "built_up"),
        start_date = c("2023-01-01", "2024-03-01", "2024-08-01"),
        end_date = c("2024-02-28", "2024-07-31", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # Construction camp/facilities: forest -> bareland -> settlement
    construction_facilities = data.frame(
        label = c("forest", "bareland", "settlement"),
        start_date = c("2023-01-01", "2024-02-01", "2024-06-01"),
        end_date = c("2024-01-31", "2024-05-31", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # Temporary clearing (revegetation): forest -> bareland -> grassland
    temporary_clearing = data.frame(
        label = c("forest", "bareland", "grassland"),
        start_date = c("2023-01-01", "2024-01-01", "2024-06-01"),
        end_date = c("2023-12-31", "2024-05-31", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # ==========================================================================
    # AGRICULTURAL CYCLES (showing seasonal changes)
    # ==========================================================================

    # Paddy rice cycle: paddy -> bareland -> paddy (2 crops/year)
    paddy_cycle = data.frame(
        label = c("paddy", "bareland", "paddy", "bareland", "paddy"),
        start_date = c("2023-01-01", "2023-05-01", "2023-06-01",
                      "2023-11-01", "2023-12-01"),
        end_date = c("2023-04-30", "2023-05-31", "2023-10-31",
                    "2023-11-30", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # Ladang (shifting cultivation): forest -> bareland -> ladang -> grassland
    ladang_cycle = data.frame(
        label = c("forest", "bareland", "ladang", "grassland"),
        start_date = c("2023-01-01", "2023-12-01", "2024-01-01", "2024-06-01"),
        end_date = c("2023-11-30", "2023-12-31", "2024-05-31", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # Agroforestry establishment: bareland -> sparse_vegetation -> agroforest
    agroforest_establishment = data.frame(
        label = c("bareland", "sparse_vegetation", "agroforest"),
        start_date = c("2023-01-01", "2023-06-01", "2024-01-01"),
        end_date = c("2023-05-31", "2023-12-31", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # ==========================================================================
    # FOREST DISTURBANCE AND SUCCESSION
    # ==========================================================================

    # Logging to production forest: natural_forest -> bareland -> production_forest
    selective_logging = data.frame(
        label = c("natural_forest", "bareland", "production_forest"),
        start_date = c("2023-01-01", "2024-01-01", "2024-03-01"),
        end_date = c("2023-12-31", "2024-02-28", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # Forest degradation: natural_forest -> sparse_vegetation -> grassland
    forest_degradation = data.frame(
        label = c("natural_forest", "sparse_vegetation", "grassland"),
        start_date = c("2023-01-01", "2024-01-01", "2024-06-01"),
        end_date = c("2023-12-31", "2024-05-31", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # Reforestation: grassland -> sparse_vegetation -> production_forest
    reforestation = data.frame(
        label = c("grassland", "sparse_vegetation", "production_forest"),
        start_date = c("2023-01-01", "2023-06-01", "2024-01-01"),
        end_date = c("2023-05-31", "2023-12-31", "2025-12-31"),
        stringsAsFactors = FALSE
    ),

    # ==========================================================================
    # STABLE CLASSES (No change - but still need temporal bounds)
    # ==========================================================================

    stable_natural_forest = data.frame(
        label = "natural_forest",
        start_date = "2023-01-01",
        end_date = "2025-12-31",
        stringsAsFactors = FALSE
    ),

    stable_production_forest = data.frame(
        label = "production_forest",
        start_date = "2023-01-01",
        end_date = "2025-12-31",
        stringsAsFactors = FALSE
    ),

    stable_agroforest = data.frame(
        label = "agroforest",
        start_date = "2023-01-01",
        end_date = "2025-12-31",
        stringsAsFactors = FALSE
    ),

    stable_grassland = data.frame(
        label = "grassland",
        start_date = "2023-01-01",
        end_date = "2025-12-31",
        stringsAsFactors = FALSE
    ),

    stable_settlement = data.frame(
        label = "settlement",
        start_date = "2023-01-01",
        end_date = "2025-12-31",
        stringsAsFactors = FALSE
    ),

    stable_water = data.frame(
        label = "water",
        start_date = "2023-01-01",
        end_date = "2025-12-31",
        stringsAsFactors = FALSE
    ),

    stable_bareland = data.frame(
        label = "bareland",
        start_date = "2023-01-01",
        end_date = "2025-12-31",
        stringsAsFactors = FALSE
    )
)

cat("Defined change sequences:\n")
for (seq_name in names(change_sequences)) {
    seq_data <- change_sequences[[seq_name]]
    cat("\n", seq_name, ":\n", sep = "")
    cat("  ", paste(seq_data$label, collapse = " -> "), "\n")
    cat("  Timeline:", seq_data$start_date[1], "to",
        seq_data$end_date[nrow(seq_data)], "\n")
}

cat("\n========================================\n")
cat("Template Files Created\n")
cat("========================================\n\n")

# Create template CSV
template_csv <- "data/temporal_samples_template.csv"
template_data <- data.frame(
    area_id = 1:18,
    longitude = c(
        # Dam construction area
        106.5234, 106.5245, 106.5256, 106.5267, 106.5278,
        # Agricultural areas
        106.5289, 106.5290, 106.5291,
        # Forest areas
        106.5292, 106.5293, 106.5294,
        # Stable areas
        106.5295, 106.5296, 106.5297, 106.5298, 106.5299, 106.5300, 106.5301
    ),
    latitude = c(
        # Dam construction area
        -7.1234, -7.1245, -7.1256, -7.1267, -7.1278,
        # Agricultural areas
        -7.1289, -7.1290, -7.1291,
        # Forest areas
        -7.1292, -7.1293, -7.1294,
        # Stable areas
        -7.1295, -7.1296, -7.1297, -7.1298, -7.1299, -7.1300, -7.1301
    ),
    change_type = c(
        # Dam construction (5)
        "dam_construction", "reservoir_area_cleared", "road_construction",
        "construction_facilities", "temporary_clearing",
        # Agricultural (3)
        "paddy_cycle", "ladang_cycle", "agroforest_establishment",
        # Forest disturbance (3)
        "selective_logging", "forest_degradation", "reforestation",
        # Stable (7)
        "stable_natural_forest", "stable_production_forest", "stable_agroforest",
        "stable_grassland", "stable_settlement", "stable_water", "stable_bareland"
    ),
    notes = c(
        # Dam construction
        "Main dam construction site",
        "Future reservoir area - cleared but not flooded",
        "Access road to dam",
        "Construction camp and facilities",
        "Temporary storage area - will revegetate",
        # Agricultural
        "Paddy rice field - 2 crops per year",
        "Shifting cultivation area",
        "Agroforestry plantation being established",
        # Forest disturbance
        "Selective logging area",
        "Degraded forest area",
        "Reforestation project site",
        # Stable
        "Undisturbed natural forest",
        "Commercial timber plantation",
        "Established agroforest system",
        "Permanent grassland/pasture",
        "Village/settlement area",
        "Existing water body",
        "Permanent bareland/mining area"
    ),
    stringsAsFactors = FALSE
)

write.csv(template_data, template_csv, row.names = FALSE)
cat("Template CSV created:", template_csv, "\n")
cat("  Edit this file with your actual coordinates and change types\n\n")

# Create samples from template
output_gpkg <- "data/temporal_samples_example.gpkg"
samples <- create_temporal_samples(
    locations = template_data,
    changes = change_sequences,
    output_file = output_gpkg
)

cat("\nSample distribution:\n")
print(table(samples$label, samples$change_type))

cat("\n========================================\n")
cat("How to Use These Samples\n")
cat("========================================\n\n")

cat("1. Edit the template CSV with your locations:\n")
cat("   - Open:", template_csv, "\n")
cat("   - Update longitude/latitude coordinates\n")
cat("   - Assign appropriate change_type\n")
cat("   - Add descriptive notes\n\n")

cat("2. Modify change sequences if needed:\n")
cat("   - Edit change_sequences list in this script\n")
cat("   - Adjust dates based on your actual change timeline\n")
cat("   - Add new change types as needed\n\n")

cat("3. Generate samples:\n")
cat("   source('scripts/create_temporal_samples.R')\n")
cat("   samples <- create_temporal_samples(\n")
cat("       locations = read.csv('your_locations.csv'),\n")
cat("       changes = change_sequences,\n")
cat("       output_file = 'data/training_samples_temporal.gpkg'\n")
cat("   )\n\n")

cat("4. Combine with other samples:\n")
cat("   # Load temporal samples\n")
cat("   temporal <- st_read('data/training_samples_temporal.gpkg')\n\n")
cat("   # Load stable area samples\n")
cat("   stable <- st_read('data/training_samples_stable.gpkg')\n\n")
cat("   # Combine\n")
cat("   all_samples <- rbind(temporal, stable)\n")
cat("   st_write(all_samples, 'data/training_samples_all.gpkg')\n\n")

cat("5. Extract time series and train:\n")
cat("   cube <- readRDS('data/cube_bands_indices.rds')\n")
cat("   training <- sits_get_data(cube, all_samples)\n\n")
cat("   # sits automatically filters time series based on start_date/end_date\n")
cat("   # For each sample, only data within the valid period is used\n\n")
cat("   model <- sits_train(training, sits_rfor())\n\n")

cat("Important Notes:\n")
cat("- Same location can appear multiple times with different labels\n")
cat("- start_date/end_date define when each label is valid\n")
cat("- sits uses only the time series within the valid period for each sample\n")
cat("- Ensure dates align with your actual image acquisition dates\n\n")

cat("Visual Verification:\n")
cat("1. Open QGIS\n")
cat("2. Load temporal samples GeoPackage\n")
cat("3. Load RGB composites from different dates\n")
cat("4. Filter samples by date: start_date <= '2023-12-31' AND end_date >= '2023-01-01'\n")
cat("5. Verify labels match the imagery for each time period\n\n")
