# spec: pb_vista_pedidos_usuario

Herramienta: Kiro (especificacion previa) -> OpenCode (generacion)

## Objetivo
Reporte de pedidos con los datos del usuario para el area de atencion,
excluyendo pedidos dados de baja y NUNCA exponiendo credenciales.

## Columnas a exponer
- `pedido_id` (pedido.id)
- `fecha`, `total`, `estado` (pedido)
- `usuario_id` (usuario.id)
- `usuario` (usuario.nombre || ' ' || usuario.apellido)
- `email` (usuario.email)

## Filtros
- Pedido no eliminado: `pedido.eliminado = FALSE`.

## Seguridad
La columna `usuario.contrasena` queda oculta y JAMAS se proyecta. Esta
vista es uno de los insumos del area de atencion sin tocar credenciales.

## Criterio de aceptacion
La vista devuelve exactamente lo mismo que la consulta manual
equivalente: `EXCEPT` en ambos sentidos = 0 filas.