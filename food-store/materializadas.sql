-- ============================================================
-- Proyecto integrador: FOOD STORE
-- materializadas.sql - Parte C - Vista materializada
-- (Unidad 3, Semana 1)
-- Reporte elegido: facturacion por categoria y mes (queries.sql
-- Q11), el reporte analitico mas costoso del sistema (cruza
-- detalle_pedido x pedido x producto x categoria y agrega las
-- 600.000 lineas).
-- Especificacion origen: specs/pc_vista_materializada.md
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- Vista materializada con datos (WITH DATA)
-- Agregado por anio + mes + categoria sobre lineas NO eliminadas
-- ------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_facturacion_mensual_categoria AS
SELECT EXTRACT(YEAR FROM p.fecha)::int AS anio,
       EXTRACT(MONTH FROM p.fecha)::int AS mes,
       c.id                             AS categoria_id,
       c.nombre                         AS categoria,
       ROUND(SUM(d.cantidad * d.precio_unitario)::numeric, 2) AS facturacion
FROM detalle_pedido d
JOIN pedido    p  ON p.id  = d.pedido_id  AND p.eliminado = FALSE
JOIN producto  pr ON pr.id = d.producto_id
JOIN categoria c  ON c.id  = pr.categoria_id
GROUP BY anio, mes, c.id, c.nombre
ORDER BY anio, mes, categoria
WITH DATA;

-- ------------------------------------------------------------
-- Indice UNICO sobre la clave natural (anio, mes, categoria_id).
-- Requisito para poder usar, en el futuro, REFRESH CONCURRENTLY
-- (PostgreSQL exige al menos un indice unico en la matview).
-- ------------------------------------------------------------
CREATE UNIQUE INDEX idx_uq_mv_facturacion_mensual_cat
    ON mv_facturacion_mensual_categoria (anio, mes, categoria_id);

COMMIT;