-- ============================================================
-- Proyecto integrador: FOOD STORE
-- queries.sql - Consultas de negocio y analiticas (Semanas 3-4)
-- Fuente de la carga de trabajo real a indexar en la Unidad 3.
-- Comentario indica frecuencia de uso y que columnas participan
-- del filtro / JOIN / ORDER BY.
-- ============================================================

-- ------------------------------------------------------------
-- Q1. Cartilla / menu: productos vigentes de una categoria con
-- rango de precio, ordenados por precio.   [frecuencia: ALTA]
-- Filtro: categoria_id, activo, precio | ORDER BY precio
-- ------------------------------------------------------------
SELECT nombre, precio
FROM producto
WHERE categoria_id = 1
  AND activo = TRUE
  AND precio BETWEEN 500 AND 1200
ORDER BY precio
LIMIT 20;

-- ------------------------------------------------------------
-- Q2. Busqueda de producto por nombre parcial.   [frecuencia: ALTA]
-- Filtro: nombre ILIKE '%...%', activo
-- ------------------------------------------------------------
SELECT id, nombre, precio
FROM producto
WHERE nombre ILIKE '%Bebidas%500ml%'
  AND activo = TRUE;

-- ------------------------------------------------------------
-- Q3. Conteo de pedidos de enero 2025 (EXTRACT no sargable).
-- [frecuencia: MEDIA] Filtro: fecha (funcion sobre la columna)
-- ------------------------------------------------------------
SELECT COUNT(*)
FROM pedido
WHERE EXTRACT(MONTH FROM fecha) = 1
  AND EXTRACT(YEAR  FROM fecha) = 2025
  AND eliminado = FALSE;

-- ------------------------------------------------------------
-- Q4. Reporte mensual: pedidos CONFIRMADOS de un rango de fechas
-- con su total.   [frecuencia: ALTA] Filtro: fecha, estado, eliminado
-- ------------------------------------------------------------
SELECT id, fecha, total
FROM pedido
WHERE fecha BETWEEN '2025-03-01 00:00:00+00' AND '2025-03-31 23:59:59+00'
  AND estado = 'CONFIRMADO'
  AND eliminado = FALSE
ORDER BY fecha;

-- ------------------------------------------------------------
-- Q5. Historial de ventas de un producto: cruza detalle_pedido,
-- pedido y producto.   [frecuencia: ALTA] Filtro: producto_id
-- ------------------------------------------------------------
SELECT p.id, p.fecha, pr.nombre AS producto,
       d.cantidad,
       d.cantidad * d.precio_unitario AS subtotal
FROM detalle_pedido d
JOIN pedido   p  ON p.id  = d.pedido_id
JOIN producto pr ON pr.id = d.producto_id
WHERE d.producto_id = 100
ORDER BY p.fecha DESC
LIMIT 50;

-- ------------------------------------------------------------
-- Q6. Top 100 pedidos recientes con usuario y total.
-- [frecuencia: MEDIA] JOIN y agregacion con LIMIT tardio
-- ------------------------------------------------------------
SELECT p.id, p.fecha,
       u.nombre || ' ' || u.apellido AS usuario,
       SUM(d.cantidad * d.precio_unitario) AS total
FROM pedido p
JOIN usuario u        ON u.id  = p.usuario_id
JOIN detalle_pedido d ON d.pedido_id = p.id
WHERE p.eliminado = FALSE
GROUP BY p.id, p.fecha, u.nombre, u.apellido
ORDER BY p.fecha DESC
LIMIT 100;

-- ------------------------------------------------------------
-- Q7. Resumen: cantidad de productos vigentes por categoria.
-- [frecuencia: MEDIA] Filtro: vigencia
-- ------------------------------------------------------------
SELECT c.nombre,
       COUNT(p.id) AS cantidad_productos
FROM categoria c
LEFT JOIN producto p ON p.categoria_id = c.id
                    AND p.activo = TRUE
WHERE c.activo = TRUE
GROUP BY c.id, c.nombre
ORDER BY cantidad_productos DESC, c.nombre;

-- ------------------------------------------------------------
-- Q8. Usuarios vigentes cuyo gasto total supera el promedio.
-- [frecuencia: BAJA] JOIN x3 + agregacion
-- ------------------------------------------------------------
SELECT u.id, u.nombre, u.apellido,
       COALESCE(SUM(d.cantidad * d.precio_unitario), 0) AS gasto_total
FROM usuario u
LEFT JOIN pedido p        ON p.usuario_id = u.id
LEFT JOIN detalle_pedido d ON d.pedido_id  = p.id
WHERE u.activo = TRUE
GROUP BY u.id, u.nombre, u.apellido
HAVING COALESCE(SUM(d.cantidad * d.precio_unitario), 0) > (
    SELECT AVG(g) FROM (
        SELECT COALESCE(SUM(d2.cantidad * d2.precio_unitario), 0) AS g
        FROM usuario u2
        LEFT JOIN pedido p2         ON p2.usuario_id = u2.id
        LEFT JOIN detalle_pedido d2 ON d2.pedido_id  = p2.id
        WHERE u2.activo = TRUE
        GROUP BY u2.id) AS t)
ORDER BY gasto_total DESC, u.id;

-- ------------------------------------------------------------
-- Q9. Ranking de usuarios por gasto total (RANK con huecos).
-- [frecuencia: BAJA] Ventana sobre agregacion
-- ------------------------------------------------------------
SELECT u.id, u.nombre, u.apellido,
       SUM(d.cantidad * d.precio_unitario) AS gasto,
       RANK() OVER (ORDER BY SUM(d.cantidad * d.precio_unitario) DESC) AS puesto
FROM usuario u
JOIN pedido p         ON p.usuario_id = u.id
JOIN detalle_pedido d ON d.pedido_id  = p.id
WHERE u.activo = TRUE
GROUP BY u.id, u.nombre, u.apellido
ORDER BY puesto, u.id;

-- ------------------------------------------------------------
-- Q10. Pedidos del usuario id = 6 con su total.
-- [frecuencia: BAJA] Filtro: usuario_id + agregacion
-- ------------------------------------------------------------
SELECT p.id, p.fecha,
       SUM(d.cantidad * d.precio_unitario) AS total
FROM pedido p
JOIN detalle_pedido d ON d.pedido_id = p.id
WHERE p.usuario_id = 6
GROUP BY p.id, p.fecha
ORDER BY p.fecha, p.id;

-- ------------------------------------------------------------
-- Q11. Reporte analitico: facturacion por categoria y mes.
-- [frecuencia: BAJA (reporte / tabla de director)] Costosa.
-- JOIN x3 + agrupacion sobre millones de lineas.
-- ------------------------------------------------------------
SELECT EXTRACT(YEAR FROM p.fecha)::int AS anio,
       EXTRACT(MONTH FROM p.fecha)::int AS mes,
       c.id AS categoria_id,
       c.nombre AS categoria,
       ROUND(SUM(d.cantidad * d.precio_unitario)::numeric, 2) AS facturacion
FROM detalle_pedido d
JOIN pedido    p ON p.id = d.pedido_id  AND p.eliminado = FALSE
JOIN producto  pr ON pr.id = d.producto_id
JOIN categoria c ON c.id = pr.categoria_id
GROUP BY anio, mes, c.id, c.nombre
ORDER BY anio, mes, categoria;

-- ------------------------------------------------------------
-- Q12. Login: busqueda de usuario por email.   [frecuencia: MUY ALTA]
-- Filtro: email (y activo)
-- ------------------------------------------------------------
SELECT id, nombre, apellido, contrasena
FROM usuario
WHERE email = 'usuario1234@mail.com'
  AND activo = TRUE;