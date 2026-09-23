# spec: pb_vista_productos_vigentes

Herramienta: Kiro (especificacion previa) -> OpenCode (generacion)

## Objetivo
Estandarizar el reporte de cartilla/menu: productos vigentes con el
nombre de su categoria, sin exponer columnas internas del modelo.

## Columnas a exponer
- `producto_id` (producto.id)
- `producto` (producto.nombre)
- `precio` (producto.precio)
- `categoria` (categoria.nombre)

## Filtros
- Vigencia del producto: `producto.activo = TRUE`.
- Vigencia de la categoria: `categoria.activo = TRUE`.

## Seguridad
No se expone `producto.activo` ni el id de categoria (se entrega el
nombre legible); el consumidor de la vista no necesita las tablas base.

## Criterio de aceptacion
La vista devuelve exactamente lo mismo que la consulta manual
equivalente: `EXCEPT` en ambos sentidos = 0 filas.