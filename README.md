# Mappa densita ristoranti - Sud della Francia

Questo progetto genera una mappa di densita dei ristoranti nel sud della Francia usando dati geografici e OpenStreetMap.

Lo script principale (`south_france_restaurant_density.R`) fa tutto in automatico:

- installa i pacchetti R mancanti in `.Rlibs`
- scarica i ristoranti da OpenStreetMap (con fallback a dataset pubblici se necessario)
- prepara i confini geografici dell'area di interesse
- crea una heatmap di densita con `ggplot2`
- salva l'immagine finale in `south_france_restaurant_density.png`

## Come eseguirlo

```bash
Rscript south_france_restaurant_density.R
```

## Output generati

- `south_france_restaurant_density.png` (mappa finale)
- `data/restaurants_south_france.csv` (dataset locale ristoranti)
- `data/south_france_boundaries.geojson` (confini geografici locali)

