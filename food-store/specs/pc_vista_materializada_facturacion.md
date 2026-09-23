# spec: pc_vista_materializada_facturacion

Herramienta: Kiro (especificacion previa) -> OpenCode (generacion)

## Objetivo
Materializar el reporte agregado mas costoso del sistema: facturacion
por categoria y mes, que hoy agrega las 600.000 lineas de
`detalle_pedido` en ~300 ms cada ejecucion. Se quiere responder al
instante a la "tabla de director".

## Consulta origen (queries.sql Q11)
```sql
SELECT EXTRACT(YEAR FROM p.fecha)::int AS anio,
       EXTRACT(MONTH FROM p.fecha)::int AS mes,
       c.id AS categoria_id,
       c.nombre AS categoria,
       ROUND(SUM(d.cantidad * d.precio_unitario)::numeric, 2) AS facturacion
FROM detalle_pedido d
JOIN pedido    p  ON p.id = d.pedido_id AND p.eliminado = FALSE
JOIN producto  pr ON pr.id = d.producto_id
JOIN categoria c  ON c.id  = pr.categoria_id
GROUP BY anio, mes, c.id, c.nombre
ORDER BY anio, mes, categoria;
```

## Requisitos
- `CREATE MATERIALIZED VIEW ... WITH DATA`.
- Indice UNICO sobre la clave natural `(anio, mes, categoria_id)`, que
  habilita a futuro un `REFRESH CONCURRENTLY`.

## Criterio de aceptacion
- El tiempo de consulta contra la vista materializada es al menos
  2 ordenes de magnitud menor que la consulta original (objetivo: de
  ~300 ms a <3 ms).
- El indice unico existe (habilitacion de REFRESH CONCURRENTLY).
- Se documenta la frecuencia de refresco y que implica la foto
  (stale) para los consumidores.