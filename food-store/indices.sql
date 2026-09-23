-- ============================================================
-- Proyecto integrador: FOOD STORE
-- indices.sql - Parte A - Plan de indexado (Unidad 3, Semana 1)
-- Cada indice responde a UNA consulta de la carga de trabajo
-- (queries.sql) y su aceptacion fue decidida con EXPLAIN ANALYZE
-- antes/despues (ver informe_mediciones.md y mediciones/).
-- Especificaciones origen: specs/*.md
-- ============================================================

-- En PostgreSQL, los CREATE INDEX pueden ejecutarse dentro de una
-- transaccion. Protocolo: BEGIN; ...; COMMIT; (rollback si el
-- plan no mejora).

BEGIN;

-- ------------------------------------------------------------
-- Indice 1 - Indice compuesto PARCIAL sobre pedido
-- Consulta: QF1 "reporte mensual de pedidos CONFIRMADOS"
-- (queries.sql Q4):
--   SELECT id, fecha, total FROM pedido
--   WHERE fecha BETWEEN '2025-03-01' AND '2025-03-31'
--     AND estado = 'CONFIRMADO' AND eliminado = FALSE
--     ORDER BY fecha;
-- PLAN ANTES : Parallel Seq Scan sobre pedido (200.000 filas)
--              Execution Time ~51 ms
-- Por que asi:
--   * fecha es la columna mas selectiva (rango over 630 dias).
--   * estado tiene cardinalidad baja (4 valores), se incluye como
--     segunda columna para entregar filas ya filtradas por estado.
--   * WHERE NOT eliminado: indice PARCIAL para que las columnas
--     bajas no paguen mantenimiento sobre pedidos dados de baja
--     y el indice sea mas compacto.
-- Criterio aceptacion: pasar a Index/Index Only Scan y bajar el
-- tiempo real al menos un orden de magnitud.
-- ------------------------------------------------------------
CREATE INDEX idx_pedido_fecha_estado_vig
    ON pedido (fecha, estado)
    WHERE NOT eliminado;

-- ------------------------------------------------------------
-- Indice 2 - Indice btree simple sobre detalle_pedido
-- Consulta: QF2 "historial de ventas de un producto"
-- (queries.sql Q5):
--   SELECT ... FROM detalle_pedido d JOIN pedido p ...
--   JOIN producto pr ... WHERE d.producto_id = 100 ... LIMIT 50;
-- PLAN ANTES : Parallel Seq Scan sobre detalle_pedido (600.000
--              filas; 199.993 removidas por filtro) ~147 ms
-- Por que asi:
--   * filtro puntual muy selectivo (un producto entre 50.000).
--   * el Nested Loop por PK (pedido, producto) estaba bien; el
--     cuello era barrer TODA la tabla de lineas para hallar las
--     ~20 de un producto. El indice convierte el acceso a la
--     tabla externa del Nested Loop en Bitmap Index Scan.
-- Criterio aceptacion: el Parallel Seq Scan sobre detalle_pedido
-- desaparece; tiempo real cae al menos un orden de magnitud.
-- ------------------------------------------------------------
CREATE INDEX idx_detalle_pedido_producto
    ON detalle_pedido (producto_id);

-- ------------------------------------------------------------
-- Indice 3 - Indice GIN de trigramas (pg_trgm) PARCIAL
-- Consulta: QF3 "busqueda de producto por nombre parcial"
-- (queries.sql Q2):
--   SELECT id, nombre, precio FROM producto
--   WHERE nombre ILIKE '%Bebidas%500ml%' AND activo = TRUE;
-- PLAN ANTES : Seq Scan sobre producto (50.000 filas) ~39 ms
-- Por que asi:
--   * un patron LIKE '%...%' NO puede resolverse con un indice
--     btree (ni con el heredado idx_producto_nombre_vig). Solo un
--     GIN de trigramas permite Index Scan para patrones con
--     comodin al inicio.
--   * WHERE activo = TRUE: parcial, igual criterio de vigencia.
--   * el btree herdado idx_producto_nombre_vig se mantiene: sigue
--     sirviendo prefijos/orden y es index-only para vigentes.
-- Criterio aceptacion: pasar de Seq Scan a Bitmap (GIN) Scan con
-- mejora de tiempo respetable.
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_producto_nombre_trgm
    ON producto USING gin (nombre gin_trgm_ops)
    WHERE activo = TRUE;

-- ============================================================
-- PROPUESTAS DESCARTADAS POR SOBREINDEXACION
-- (justificacion completa en informe_mediciones.md)
-- ------------------------------------------------------------
-- 1) idx_pedido_estado ON pedido(estado)  [DESCARTADO]
--    cardinalidad = 4 valores (PENDIENTE/CONFIRMADO/CANCELADO/
--    ENTREGADO). Un indice solo sobre estado no es selectivo y el
--    optimizador lo ignora; ademas es REDUNDANTE con
--    idx_pedido_fecha_estado_vig (misma columna como prefijo
--    compuesto). Su unica version util seria parcial (estado IN
--    (...)), que ya queda cubierta por el compuesto parcial.
-- 2) idx_detalle_pedido_pedido ON detalle_pedido(pedido_id)
--    [DESCARTADO]
--    Los JOIN de detalle con pedido se resuelven por pedido_pkey;
--    indizar la FK no cambia el plan de las consultas de reporte
--    que agregan todas las lineas. Costo de mantenimiento en
--    escritura sin beneficio de lectura medible en el plan real.
COMMIT;