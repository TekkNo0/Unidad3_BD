# spec: pb_vista_detalle_pedido_producto

Herramienta: Kiro (especificacion previa) -> OpenCode (generacion)

## Objetivo
Detalle de un pedido con el nombre del producto (en lugar del codigo)
para los reportes de facturacion / ticket.

## Columnas a exponer
- `detalle_id` (detalle_pedido.id)
- `pedido_id` (detalle_pedido.pedido_id)
- `producto` (producto.nombre)
- `cantidad`, `precio_unitario` (detalle_pedido)
- `subtotal` = cantidad x precio_unitario (derivada)

## Filtros
Ninguno (la vista sirve para cualquier pedido; el filtro por pedido lo
pone el consumidor de la vista en el `WHERE`).

## Seguridad
No se exponen los ids internos de producto ni las columnas de credito
internas del detalle.

## Criterio de aceptacion
La vista devuelve exactamente lo mismo que la consulta manual
equivalente: `EXCEPT` en ambos sentidos = 0 filas.