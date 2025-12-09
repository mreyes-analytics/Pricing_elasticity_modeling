library(tidyverse)
library(lubridate)

set.seed(123)

# Sucursales
sucursales <- paste0("X", 1:9)

# Segmentos ficticios
segmentos <- tibble(
  SUCURSAL = sucursales,
  SEGMENT = c(
    "Segment_1", "Segment_1", "Segment_1",
    "Segment_1", "Segment_1", "Segment_1",
    "Segment_2", "Segment_2", "Segment_3"
  )
)

# Elasticidades deseadas
elasticidades <- tibble(
  SEGMENT = c("Segment_1", "Segment_2", "Segment_3"),
  ELAST = c(-0.25, -1.4, -3.5)  # inelastic, elastic, very elastic
)

# Rango meses
meses <- seq(as.Date("2023-01-01"), as.Date("2025-12-01"), by = "month")

# Precio base por segmento
precio_base <- c(
  Segment_1 = 260,
  Segment_2 = 230,
  Segment_3 = 200
)

# Volumen base
volumen_base <- c(
  Segment_1 = 1600,
  Segment_2 = 4500,
  Segment_3 = 28000
)

# Generador con elasticidad económica
generar_datos <- function(sucursal, segmento, mes, elast, p0, v0) {
  
  # Precio fluctúa mes a mes
  precio <- p0 * runif(1, 0.9, 1.1)
  
  # Demanda responde al precio: Q = Q0 * (P/P0)^elasticidad
  bultos <- v0 * (precio / p0)^elast
  bultos <- round(bultos * runif(1, 0.9, 1.1))  # ruido aleatorio
  
  ventas <- bultos * precio
  costo <- ventas * runif(1, 0.80, 0.94)
  utilidad <- ventas - costo
  
  tibble(
    SUCURSAL   = sucursal,
    SEGMENT    = segmento,
    MES        = mes,
    BULTOS     = bultos,
    TONELADAS  = bultos / 20,
    PRECIO_VTA = precio,
    VENTAS     = ventas,
    COSTO      = costo,
    UTILIDAD   = utilidad,
    UTILIDAD_PCT = utilidad / ventas,
    MARGEN_PCT   = utilidad / costo
  )
}

# Generar dataset completo
dummy_data <- map_dfr(1:nrow(segmentos), function(i) {
  
  seg <- segmentos$SEGMENT[i]
  
  map_dfr(meses, function(m) generar_datos(
    sucursal = segmentos$SUCURSAL[i],
    segmento = seg,
    mes      = m,
    elast    = elasticidades$ELAST[elasticidades$SEGMENT == seg],
    p0       = precio_base[[seg]],
    v0       = volumen_base[[seg]]
  ))
})

# Guardar
dir.create("data", showWarnings = FALSE)
write_csv(dummy_data, "data/cement_dummy_data.csv")
