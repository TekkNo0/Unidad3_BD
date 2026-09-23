# spec: pb_vista_seguridad_usuarios

Herramienta: Kiro (especificacion previa) -> OpenCode (generacion)

## Objetivo
Criterio de seguridad de la teoria: exponer el usuario SIN la columna
contraseña, de modo que pueda otorgarse SELECT sobre la vista sin dar
acceso a la tabla base `usuario`.

## Columnas a exponer
- `id`, `nombre`, `apellido`, `email`, `activo`

## Columnas a ocultar
- `contrasena` (hash de la credencial). Es la razon de existir de esta
  vista: el rol de reportes consume la vista y nunca toca la tabla.

## Filtros
- Usuarios activos: `usuario.activo = TRUE`.

## Criterio de aceptacion
1. La vista no contiene la columna `contrasena` en su esquema.
2. Se otorga `GRANT SELECT ON v_usuarios_sin_contrasena` sin grant sobre
   la tabla base.
3. Equivalencia con la consulta manual `EXCEPT` = 0 filas en ambos sentidos.