-- ============================================================
-- Proyecto integrador: FOOD STORE
-- data.sql - Datos de carga (Semanas 2 a 4) ampliados
-- para que las diferencias de plan y tiempo sean observables.
-- Volumen objetivo: decenas de miles de filas en producto y
-- usuario, cientos de miles en pedido y detalle_pedido.
-- Carga en una UNICA transaccion (protocolo de la catedra).
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- Categorias (10; una queda inactiva para ejercitar filtros de vigencia)
-- ------------------------------------------------------------
INSERT INTO categoria (nombre, activo) VALUES
    ('Bebidas',    TRUE),
    ('Pizzas',     TRUE),
    ('Empanadas',  TRUE),
    ('Sandwiches', TRUE),
    ('Ensaladas',  TRUE),
    ('Postres',    TRUE),
    ('Cafe',       TRUE),
    ('Snacks',     TRUE),
    ('Salsas',     TRUE),
    ('Combos',     FALSE);

-- ------------------------------------------------------------
-- Productos: 50.000 filas (generate_series, sin PL/pgSQL)
--   activo = FALSE en ~1% de las filas (vigencia no vigente)
-- ------------------------------------------------------------
INSERT INTO producto (nombre, precio, categoria_id, activo)
SELECT
    'Producto ' || c.nombre || ' ' || n || ' ' || (500 + (n % 25)) || 'ml',
    ROUND((500 + ((n * 37) % 1000) + ((n * 7) % 100) / 100.0)::numeric, 2),
    1 + (n % 10),
    CASE WHEN (n % 97 = 0) THEN FALSE ELSE TRUE END
FROM generate_series(1, 50000) AS n
JOIN categoria c ON c.id = 1 + (n % 10);

-- ------------------------------------------------------------
-- Usuarios: 20.000 filas
--   activo = FALSE en el 4% (bajas logicas)
-- ------------------------------------------------------------
INSERT INTO usuario (nombre, apellido, email, contrasena, activo)
SELECT
    'Usuario'  || n,
    'Apellido' || n,
    'usuario'  || n || '@mail.com',
    md5('seed-' || n),
    CASE WHEN (n % 25 = 0) THEN FALSE ELSE TRUE END
FROM generate_series(1, 20000) AS n;

-- ------------------------------------------------------------
-- Pedidos: 200.000 filas
--   estado ponderado: CONFIRMADO (50%), ENTREGADO (30%),
--   PENDIENTE (10%), CANCELADO (10%)
--   eliminado = TRUE en el 5% de los pedidos (baja logica)
--   total en 0 (se recalcula al final con las lineas)
-- ------------------------------------------------------------
INSERT INTO pedido (usuario_id, fecha, total, estado, eliminado)
SELECT
    1 + (n % 20000),
    TIMESTAMPTZ '2025-01-01 00:00:00+00'
        + ((n % 630) || ' days')::interval
        + ((n % 24)  || ' hours')::interval,
    0,
    (ARRAY['PENDIENTE','CONFIRMADO','CONFIRMADO','CONFIRMADO',
           'CONFIRMADO','CONFIRMADO','ENTREGADO','ENTREGADO',
           'ENTREGADO','CANCELADO'])[1 + (n % 10)],
    (n % 20 = 0)
FROM generate_series(1, 200000) AS n;

-- ------------------------------------------------------------
-- Detalle de pedidos: 1 a 5 lineas por pedido (~600.000 filas)
--   producto asignado por posicion deterministica: (pedido*5+k) % 50000
--   (un producto no se repite dentro del mismo pedido)
-- ------------------------------------------------------------
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT l.pedido_id,
       l.producto_id,
       l.cantidad,
       pr.precio
FROM (
    SELECT p.id AS pedido_id,
           1 + ((p.id * 5 + k) % 50000) AS producto_id,
           1 + ((p.id + k) % 10)        AS cantidad
    FROM generate_series(1, 200000) AS p(id)
    JOIN LATERAL generate_series(1, 1 + (p.id % 5)) AS k ON TRUE
) AS l
JOIN producto pr ON pr.id = l.producto_id;

-- ------------------------------------------------------------
-- Recalcular el total de cada pedido a partir de sus lineas
-- (actualizacion por conjuntos: una sola pasada sobre las lineas)
-- ------------------------------------------------------------
UPDATE pedido p
SET total = t.total
FROM (
    SELECT d.pedido_id,
           SUM(d.cantidad * d.precio_unitario) AS total
    FROM detalle_pedido d
    GROUP BY d.pedido_id
) AS t
WHERE t.pedido_id = p.id;

COMMIT;