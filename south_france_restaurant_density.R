#!/usr/bin/env Rscript

# Mappa di densita dei ristoranti nel sud della Francia (OpenStreetMap)
# Esecuzione:
#   Rscript south_france_restaurant_density.R
#
# Output:
#   south_france_restaurant_density.png
# Dati locali creati:
#   data/restaurants_south_france.csv
#   data/south_france_boundaries.geojson

required_packages <- c(
  "osmdata", "sf", "dplyr", "ggplot2", "readr",
  "rnaturalearth", "rnaturalearthdata", "viridis"
)

install_if_missing <- function(pkgs) {
  local_lib <- file.path(getwd(), ".Rlibs")
  if (!dir.exists(local_lib)) {
    dir.create(local_lib, recursive = TRUE)
  }
  .libPaths(c(local_lib, .libPaths()))

  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    install.packages(missing, repos = "https://cloud.r-project.org", lib = local_lib)
  }
}

install_if_missing(required_packages)

suppressPackageStartupMessages({
  library(osmdata)
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(rnaturalearth)
  library(viridis)
})

# Bounding box approssimativa del sud della Francia continentale
south_bbox <- c(xmin = -1.8, ymin = 42.0, xmax = 7.8, ymax = 45.8)
south_polygon <- st_as_sfc(st_bbox(south_bbox, crs = st_crs(4326)))

data_dir <- file.path(getwd(), "data")
if (!dir.exists(data_dir)) {
  dir.create(data_dir, recursive = TRUE)
}

restaurants_csv_path <- file.path(data_dir, "restaurants_south_france.csv")
boundaries_geojson_path <- file.path(data_dir, "south_france_boundaries.geojson")

fallback_restaurants_url <- "https://raw.githubusercontent.com/holtzy/R-graph-gallery/master/DATA/data_on_french_states.csv"
fallback_boundaries_url <- "https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/communes.geojson"

download_fallback <- function(url, output_path, label) {
  message(sprintf("Uso dataset di fallback per %s...", label))
  download.file(url, output_path, mode = "wb", quiet = FALSE)
}

build_restaurants_from_osm <- function() {
  message("Scarico i dati dei ristoranti da OpenStreetMap...")
  restaurant_data <- opq(bbox = south_bbox, timeout = 120) |>
    add_osm_feature(key = "amenity", value = "restaurant") |>
    osmdata_sf()

  pts <- list()

  if (!is.null(restaurant_data$osm_points) && nrow(restaurant_data$osm_points) > 0) {
    pts[["points"]] <- st_geometry(restaurant_data$osm_points)
  }

  if (!is.null(restaurant_data$osm_polygons) && nrow(restaurant_data$osm_polygons) > 0) {
    pts[["polygons"]] <- st_centroid(st_geometry(restaurant_data$osm_polygons))
  }

  if (!is.null(restaurant_data$osm_multipolygons) && nrow(restaurant_data$osm_multipolygons) > 0) {
    pts[["multipolygons"]] <- st_centroid(st_geometry(restaurant_data$osm_multipolygons))
  }

  if (length(pts) == 0) {
    stop("Nessun ristorante trovato nel bounding box specificato.")
  }

  restaurants_sf <- st_sf(geometry = do.call(c, pts), crs = 4326)
  restaurants_sf <- st_intersection(restaurants_sf, south_polygon)
  coords <- st_coordinates(restaurants_sf)

  data.frame(
    longitude = coords[, "X"],
    latitude = coords[, "Y"]
  )
}

build_boundaries_geojson <- function() {
  message("Scarico i confini della Francia e ritaglio il sud...")
  france <- ne_countries(country = "France", scale = "medium", returnclass = "sf")
  france_south <- suppressWarnings(st_intersection(france, south_polygon))
  st_write(france_south, boundaries_geojson_path, delete_dsn = TRUE, quiet = TRUE)
}

restaurants_ok <- TRUE
tryCatch({
  restaurants_local <- build_restaurants_from_osm()
  readr::write_csv(restaurants_local, restaurants_csv_path)
}, error = function(e) {
  restaurants_ok <<- FALSE
  message(sprintf("OpenStreetMap non disponibile: %s", e$message))
})

if (!restaurants_ok) {
  download_fallback(fallback_restaurants_url, restaurants_csv_path, "ristoranti")
}

boundaries_ok <- TRUE
tryCatch({
  build_boundaries_geojson()
}, error = function(e) {
  boundaries_ok <<- FALSE
  message(sprintf("Confini principali non disponibili: %s", e$message))
})

if (!boundaries_ok) {
  download_fallback(fallback_boundaries_url, boundaries_geojson_path, "confini")
}

message("Leggo i dati locali per costruire la mappa...")
restaurants_local <- readr::read_csv(restaurants_csv_path, show_col_types = FALSE)
boundaries_sf <- st_read(boundaries_geojson_path, quiet = TRUE)

colnames_lower <- tolower(names(restaurants_local))
if (all(c("longitude", "latitude") %in% colnames_lower)) {
  lon_col <- names(restaurants_local)[which(colnames_lower == "longitude")[1]]
  lat_col <- names(restaurants_local)[which(colnames_lower == "latitude")[1]]
} else if (all(c("long", "lat") %in% colnames_lower)) {
  lon_col <- names(restaurants_local)[which(colnames_lower == "long")[1]]
  lat_col <- names(restaurants_local)[which(colnames_lower == "lat")[1]]
} else {
  stop("Il CSV locale dei ristoranti non contiene colonne coordinate riconosciute.")
}

restaurants_local <- restaurants_local |>
  dplyr::rename(longitude = all_of(lon_col), latitude = all_of(lat_col)) |>
  dplyr::filter(!is.na(longitude), !is.na(latitude))

restaurants_sf <- st_as_sf(
  restaurants_local,
  coords = c("longitude", "latitude"),
  crs = 4326,
  remove = FALSE
)

if (!all(c("xmin", "ymin", "xmax", "ymax") %in% names(south_bbox))) {
  stop("Bounding box non valida.")
}

restaurants_sf <- suppressWarnings(st_intersection(restaurants_sf, south_polygon))
boundaries_sf <- suppressWarnings(st_intersection(st_make_valid(boundaries_sf), south_polygon))

if (nrow(restaurants_sf) == 0) {
  stop("Nessun ristorante disponibile nel sud della Francia dopo il filtro geografico.")
}

restaurants_l93 <- st_transform(restaurants_sf, 2154)
boundaries_l93 <- st_transform(boundaries_sf, 2154)

coords <- st_coordinates(restaurants_l93)
restaurants_df <- data.frame(x = coords[, "X"], y = coords[, "Y"])

message(sprintf("Ristoranti utilizzati per la mappa: %s", nrow(restaurants_df)))

p <- ggplot() +
  geom_sf(data = boundaries_l93, fill = "grey96", color = "grey65", linewidth = 0.2) +
  stat_density_2d_filled(
    data = restaurants_df,
    aes(x = x, y = y, fill = after_stat(level)),
    contour_var = "ndensity",
    alpha = 0.78,
    bins = 12
  ) +
  scale_fill_viridis_d(option = "magma", direction = -1, name = "Densita") +
  coord_sf(expand = FALSE) +
  labs(
    title = "Densita dei ristoranti nel sud della Francia",
    subtitle = "Dati locali: CSV ristoranti + GeoJSON confini",
    caption = "Fonte primaria: OpenStreetMap; fallback: dataset pubblici GitHub"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major = element_line(color = "grey90", linewidth = 0.2),
    plot.title = element_text(face = "bold")
  )

out_file <- "south_france_restaurant_density.png"
ggsave(out_file, p, width = 10, height = 7, dpi = 300)

message(sprintf("Mappa salvata in: %s", normalizePath(out_file)))
message(sprintf("CSV ristoranti locale: %s", normalizePath(restaurants_csv_path)))
message(sprintf("GeoJSON confini locale: %s", normalizePath(boundaries_geojson_path)))
