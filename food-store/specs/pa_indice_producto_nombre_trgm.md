# spec: indice_producto_nombre_trgm

Herramienta: Kiro (especificacion previa) -> OpenCode (generacion)

## Objetivo
Acelerar la busqueda por nombre parcial en el buscador de productos,
que hoy hace `Seq Scan` sobre los 50.000 productos (Execution Time
~39 ms). El indice btree heredado `idx_producto_nombre_vig` NO sirve
para patrones con comodin al inicio (`%...%`).

## Consulta afectada (queries.sql Q2)
```sql
SELECT id, nombre, precio
FROM producto
WHERE nombre ILIKE '%Bebidas%500ml%'
  AND activo = TRUE;
```

## Columnas candidatas
- `nombre`: unica columna del patron. Requiere extension `pg_trgm`.
- `activo`: booleano -> predicado del indice PARCIAL (igual criterio de
  vigencia que el btree heredado).

## Tipo de indice propuesto
`GIN` de trigramas `(nombre gin_trgm_ops)` con clausula parcial
`WHERE activo = TRUE`. El btree heredado `idx_producto_nombre_vig` se
mantiene (sirve prefijos y orden).

## Criterio de aceptacion
- El plan pasa de `Seq Scan` a `Bitmap Index Scan` (GIN).
- El tiempo real baja al menos un orden de magnitud (de ~39 ms a <4 ms).
- Resultado coherente con la busqueda real (mismo conjunto de filas que
  el Seq Scan honesto).