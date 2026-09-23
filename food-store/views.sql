-- ============================================================
-- Proyecto integrador: FOOD STORE
-- views.sql - Parte B - Vistas para los reportes del sistema
-- (Unidad 3, Semana 1)
-- Especificaciones origen: specs/*.md
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- V1. v_productos_vigentes
-- Productos vigentes con el nombre de su categoria.
-- Columnas expuestas: solo lo que necesita el reporte de
-- cartilla/menu. Filtro de vigencia: producto.activo AND
-- categoria.activo.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT p.id            AS producto_id,
       p.nombre        AS producto,
       p.precio,
       c.nombre        AS categoria
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE p.activo = TRUE
  AND c.activo = TRUE;

-- ------------------------------------------------------------
-- V2. v_pedidos_usuario
-- Pedidos no eliminados con los datos del usuario.
-- Columnas seguras (NUNCA se incluye contrasena): la vista
-- sirve al area de atencion sin revelar credenciales.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_pedidos_usuario AS
SELECT p.id                 AS pedido_id,
       p.fecha,
       p.total,
       p.estado,
       u.id                 AS usuario_id,
       u.nombre || ' ' || u.apellido AS usuario,
       u.email
FROM pedido p
JOIN usuario u ON u.id = p.usuario_id
WHERE p.eliminado = FALSE;

-- ------------------------------------------------------------
-- V3. v_detalle_pedido_producto
-- Detalle de un pedido con el nombre del producto y subtotal.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_detalle_pedido_producto AS
SELECT d.id               AS detalle_id,
       d.pedido_id,
       pr.nombre          AS producto,
       d.cantidad,
       d.precio_unitario,
       d.cantidad * d.precio_unitario AS subtotal
FROM detalle_pedido d
JOIN producto pr ON pr.id = d.producto_id;

-- ------------------------------------------------------------
-- V4. v_usuarios_sin_contrasena  [CRITERIO DE SEGURIDAD]
-- Expone el usuario SIN la columna contrasena (y sin la
-- credencial interna id enriquecida). Permite otorgar SELECT
-- sobre la vista a un rol de reportes sin dar acceso a la
-- tabla base usuario (y por lo tanto sin exponer hashes).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_usuarios_sin_contrasena AS
SELECT id,
       nombre,
       apellido,
       email,
       activo
FROM usuario
WHERE activo = TRUE;

-- Ejemplo de otorgamiento de permisos a un rol de reportes:
GRANT SELECT ON v_usuarios_sin_contrasena TO PUBLIC;

COMMIT;

-- ============================================================
-- Verificacion de EQUIVALENCIA de resultados
-- Cada vista se contrasta contra la consulta manual equivalente
-- con EXCEPT en ambos sentidos: 0 filas en cada sentido
-- (resultados capturados en mediciones/verificacion_vistas.out).
-- Generadas y ejecutadas por separado, nunca dentro de la
-- transaccion de creacion.
-- ============================================================

-- 1) v_productos_vigentes
--    manual:
--      SELECT p.id, p.nombre, p.precio, c.nombre
--      FROM producto p JOIN categoria c ON c.id = p.categoria_id
--      WHERE p.activo AND c.activo;

-- 2) v_pedidos_usuario
--    manual:
--      SELECT p.id, p.fecha, p.total, p.estado, u.id,
--             u.nombre || ' ' || u.apellido, u.email
--      FROM pedido p JOIN usuario u ON u.id = p.usuario_id
--      WHERE NOT p.eliminado;

-- 3) v_detalle_pedido_producto
--    manual:
--      SELECT d.id, d.pedido_id, pr.nombre, d.cantidad,
--             d.precio_unitario, d.cantidad * d.precio_unitario
--      FROM detalle_pedido d JOIN producto pr ON pr.id = d.producto_id;

-- 4) v_usuarios_sin_contrasena
--    manual:
--      SELECT id, nombre, apellido, email, activo
--      FROM usuario WHERE activo = TRUE;

-- Sentencias EXCEPT ejecutadas (resultados en
-- mediciones/verificacion_vistas.out):
--   SELECT count(*) FROM (vista EXCEPT manual) d;  -> 0
--   SELECT count(*) FROM (manual EXCEPT vista) d;  -> 0