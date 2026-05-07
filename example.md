# Cos’è una chloropleth?

Una **chloropleth** (o cloropleta) è una mappa tematica in cui aree geografiche (regioni, paesi, distretti) vengono colorate in base al valore di una variabile.

---

## A cosa serve

- Visualizzare distribuzioni geografiche di dati statistici
- Confrontare aree sullo stesso indicatore (densità, tasso, percentuale, ...)
- Identificare *pattern* spaziali: cluster, gradienti, anomalie

---

## Buone pratiche

- Usa palette **sequenziali** per dati ordinati (es. densità di popolazione)
- Usa palette **divergenti** per dati con un punto neutro (es. variazione percentuale)
- Normalizza per area o popolazione, altrimenti la mappa mostra solo *"dove vivono le persone"*
- Indica sempre unità di misura e fonte dei dati

---

## Librerie principali in R

| Libreria | Scopo |
|----------|------|
| `sf` | geometrie vettoriali (shapefile, GeoJSON, ...) |
| `ggplot2` | visualizzazione, mappe via `geom_sf()` |
| `tmap` | mappe tematiche, statiche e interattive |
| `leaflet` | mappe interattive in HTML |

---

## Esempio minimo

```r
library(sf)
library(ggplot2)
library(dplyr)

regions <- st_read("regioni.geojson")
data <- read.csv("dati.csv")

regions |>
  left_join(data, by = "regione") |>
  ggplot() +
  geom_sf(aes(fill = densita)) +
  scale_fill_viridis_c() +
  theme_minimal()