# spec: indice_pedido_fecha_estado

Herramienta: Kiro (especificacion previa) -> OpenCode (generacion)

## Objetivo
Acelerar el reporte frecuente "pedidos CONFIRMADOS de un mes" que hoy
resuelve con `Parallel Seq Scan` sobre `pedido` (200.000 filas,
Execution Time ~51 ms).

## Consulta afectada (queries.sql Q4)
```sql
SELECT id, fecha, total
FROM pedido
WHERE fecha BETWEEN '2025-03-01 00:00:00+00' AND '2025-03-31 23:59:59+00'
  AND estado = 'CONFIRMADO'
  AND eliminado = FALSE
ORDER BY fecha;
```

## Columnas candidatas
- `fecha`: alta selectividad (rango sobre 630 dias de datos, >= 2025-01).
- `estado`: baja selectividad (4 valores), segunda columna del compuesto.
- `eliminado`: booleano -> usado como predicado del indice PARCIAL para
  que el indice no mantenga los pedidos dados de baja.

## Tipo de indice propuesto
`btree` compuesto `(fecha, estado)` con clausula parcial `WHERE NOT eliminado`.

## Criterio de aceptacion
- El plan pasa de `Parallel Seq Scan` a `Index Scan`/`Bitmap Index Scan`.
- El Execution Time real baja al menos un orden de magnitud (de ~51 ms
  a menos de ~10 ms).
- Si la medicion no confirma el cambio, se descarta y se reevalua.