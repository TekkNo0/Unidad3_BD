# spec: indice_detalle_pedido_producto

Herramienta: Kiro (especificacion previa) -> OpenCode (generacion)

## Objetivo
Acelerar la consulta "historial de ventas de un producto" que hoy cruza
`detalle_pedido` (600.000 filas) con `pedido` y `producto` resolviendo
con `Parallel Seq Scan` sobre la tabla de lineas (199.993 filas
removidas por filtro; Execution Time ~147 ms).

## Consulta afectada (queries.sql Q5)
```sql
SELECT p.id, p.fecha, pr.nombre AS producto,
       d.cantidad,
       d.cantidad * d.precio_unitario AS subtotal
FROM detalle_pedido d
JOIN pedido   p  ON p.id  = d.pedido_id
JOIN producto pr ON pr.id = d.producto_id
WHERE d.producto_id = 100
ORDER BY p.fecha DESC
LIMIT 50;
```

## Columnas candidatas
- `producto_id`: filtro puntual, selectividad muy alta (1 producto de
  50.000). Nodos de JOIN por PK (`pedido_pkey`, `producto_pkey`).
- `pedido_id`: NO se indiza (los JOIN por PK ya usan pedido_pkey).

## Tipo de indice propuesto
`btree` simple sobre `detalle_pedido(producto_id)`.

## Criterio de aceptacion
- El `Parallel Seq Scan` sobre `detalle_pedido` desaparece del plan.
- El tiempo real cae al menos un orden de magnitud (de ~147 ms a <15 ms).
- El algoritmo de join (Nested Loop por PK) debe mantenerse o mejorar;
  el indice ataca el metodo de acceso del nodo externo, no el join.