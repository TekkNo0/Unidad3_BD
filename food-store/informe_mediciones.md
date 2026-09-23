# Informe de mediciones — Índices, vistas y vista materializada (Food Store)

Proyecto: Food Store · Unidad 3, Semana 1 · Base de Datos II

- Base de trabajo: `foodstore_u3_tp` (copia creada por `createdb -T` desde
  `foodstore_plantilla`, siguiendo el protocolo de seguridad de la cátedra).
- Motor: PostgreSQL 17 (localhost:5432).
- Volumen: `producto` 50.000 · `usuario` 20.000 · `pedido` 200.000 ·
  `detalle_pedido` 600.000 · `categoria` 10.
- Evidencia completa (planes `EXPLAIN (ANALYZE, VERBOSE, BUFFERS)`): carpeta `mediciones/`.

---

## Parte A — Plan de indexado

En la carga de trabajo de `queries.sql` se identificaron tres consultas
frecuentes que resolvían con `Seq Scan` sobre tablas de tamaño
considerable. Para cada una se ejecutó `EXPLAIN ANALYZE` **antes** de crear
el índice propuesto, se creó, y se volvió a medir **después**.

### QF1 — Reporte mensual de pedidos CONFIRMADOS (queries.sql Q4)
Índice creado: **`idx_pedido_fecha_estado_vig`** — btree compuesto `(fecha,
estado)` parcial `WHERE NOT eliminado` (`indices.sql`).

| Fase | Plan (nodo dominante) | Execution Time |
|---|---|---|
| Antes | `Parallel Seq Scan` sobre `pedido` (3.213 buffers, sort posterior) | **51,604 ms** |
| Después | `Bitmap Index Scan` (idx_pedido_fecha_estado_vig) + `Bitmap Heap Scan` + Sort | **6,161 ms** |

Mejora: **~8,4×** (un orden de magnitud). El Seq Scan completo de 200.000
filas desaparece; el Bitmap lee solo los bloques de los pedidos
CONFIRMADOS del mes (4.770 filas).

### QF2 — Historial de ventas de un producto (queries.sql Q5)
Índice creado: **`idx_detalle_pedido_producto`** — btree simple sobre
`detalle_pedido(producto_id)`.

| Fase | Plan (nodo dominante) | Execution Time |
|---|---|---|
| Antes | `Parallel Seq Scan` sobre `detalle_pedido` (199.993 filas removidas por filtro por worker) | **147,547 ms** |
| Después | `Bitmap Index Scan` (idx_detalle_pedido_producto) + `Bitmap Heap Scan`, Nested Loop por PK | **0,533 ms** |

Mejora: **~277×**. El algoritmo de join no cambió (el Nested Loop por PK
era correcto); cambió el método de acceso del nodo externo. El cuello era
barrer 600.000 líneas para hallar un producto.

### QF3 — Búsqueda de producto por nombre parcial (queries.sql Q2)
Índice creado: **`idx_producto_nombre_trgm`** — GIN de trigramas
(`pg_trgm`) sobre `producto(nombre)` parcial `WHERE activo = TRUE`.
La extensión `pg_trgm` se habilita en `indices.sql`. El btree heredado
`idx_producto_nombre_vig` NO puede resolver `LIKE '%...%'`.

| Fase | Plan (nodo dominante) | Execution Time |
|---|---|---|
| Antes | `Seq Scan` sobre `producto` (50.000 filas, 990 resultados) | **39,234 ms** |
| Después | `Bitmap Index Scan` GIN (idx_producto_nombre_trgm) + `Bitmap Heap Scan` | **2,958 ms** |

Mejora: **~13,3×**. Los planes completos están en `mediciones/qf3_before_index.out`
y `mediciones/qf3_after_index.out`.

### Costo de los índices sobre las escrituras (mantenimiento)

Carga de `INSERT` en `detalle_pedido` (la tabla que recibe el índice nuevo
`idx_detalle_pedido_producto`), medidas en la plantilla **sin** los índices
nuevos (`foodstore_plantilla`) vs la copia **con** índices (`foodstore_u3_tp`):

| Tamaño de carga | Antes (mediana) | Después (mediana) | Delta |
|---|---|---|---|
| 400 filas (3 corridas; "varios cientos" de consigna) | ~11,7 ms | ~13,0 ms | +1,3 ms (+11%) |
| 20.000 filas (corrida estable) | 662,9 ms | 736,9 ms | +74,0 ms (+11,2%) |

El delta por fila (~+3,7 µs/fila) es el precio de mantener
`idx_detalle_pedido_producto` (y, en menor medida, los índices de `pedido`
y `producto` al insertar en tablas relacionadas). A escala de lote el costo
es pequeño frente a la mejora de lectura (277×); para INSERT transaccionales
de OLTP, ese costo por fila es el que se debe conocer y aceptar.

### Índice descartado por sobreindexación

**`idx_pedido_estado ON pedido (estado)`** — propuesto por la IA para
"acelerar filtros por estado". **Descartado** (`specs/pa_indice_descartado_estado.md`):

1. **Cardinalidad baja:** 4 valores distintos. Filtrar `estado = 'CONFIRMADO'`
   deja ~50% de 200.000 filas; el optimizador elige Seq Scan y no usa el índice.
2. **Redundante:** la columna ya es el segundo miembro del compuesto aceptado
   `idx_pedido_fecha_estado_vig` (cubre consultas `estado` solas por el
   leading-column — no por selectividad sino por cobertura parcial).
3. **Costo:** mantenimiento en cada INSERT/UPDATE de `pedido` sin ningún plan
   que mejore, verificado en el plan real (no por intuición).

---

## Parte B — Vistas para los reportes

Vistas creadas en `views.sql`:

| Vista | Propósito |
|---|---|
| `v_productos_vigentes` | Cartilla/menú: productos activos con nombre de categoría (ambas vigentes). |
| `v_pedidos_usuario` | Pedidos no eliminados con datos del usuario (sin credenciales). |
| `v_detalle_pedido_producto` | Detalle de pedido con nombre de producto y subtotal. |
| `v_usuarios_sin_contrasena` | Seguridad: usuario sin la columna `contrasena`, con `GRANT SELECT`. |

**Verificación de equivalencia** (consulta manual vs vista, `EXCEPT` en
ambos sentidos; `mediciones/verificacion_vistas.out`):

| Vista | vista EXCEPT manual | manual EXCEPT vista | Equivalente |
|---|---|---|---|
| `v_productos_vigentes` | 0 | 0 | Sí |
| `v_pedidos_usuario` | 0 | 0 | Sí |
| `v_detalle_pedido_producto` | 0 | 0 | Sí |
| `v_usuarios_sin_contrasena` | 0 | 0 | Sí |

Criterio de seguridad aplicado (teoría semanal): `v_usuarios_sin_contrasena`
no proyecta `usuario.contrasena`; se otorga `SELECT` sobre la vista sin dar
acceso a la tabla base, por lo que un rol de reportes no puede leer hashes de
contraseñas.

---

## Parte C — Vista materializada

Reporte elegido: **facturación por categoría y mes** (queries.sql Q11), el
agregado más costoso (cruza `detalle_pedido` × `pedido` × `producto` ×
`categoria` y agrega 600.000 líneas).

Objeto: `mv_facturacion_mensual_categoria` creada `WITH DATA`
(210 filas · 21 meses × 10 categorías) con índice único
`idx_uq_mv_facturacion_mensual_cat ON (anio, mes, categoria_id)`
(requisito para un futuro `REFRESH CONCURRENTLY`).

Medición (3 corridas):

| Consulta | Tiempos (ms) | Tiempo típico |
|---|---|---|
| Original (agregación total) | 301,2 / 286,9 / 309,2 | ~301 ms |
| Contra la vista materializada | 2,89 (1er acceso) / 0,24 / 0,29 | **~0,26 ms** |

Mejora en el acceso: **~1.000×** (el primer acceso carga el índice; el dato
está físico). Costo de construcción/refresco inicial: ~287 ms (aggregación
única) + 2,2 ms del índice.

**Frecuencia de refresco recomendada:** diaria, en una ventana de
mantenimiento (e.g. `REFRESH MATERIALIZED VIEW CONCURRENTLY
mv_facturacion_mensual_categoria;` después de la carga de cierre del día).
La vista es una **foto** del momento del último refresco: entre refrescos
los pedidos nuevos NO aparecen en el reporte. Eso es aceptable porque el
reporte es de dirección (agregado mensual), tolera hasta un día de desfase,
y a cambio cada lectura cuesta 0,26 ms. Para un dato que debiera verse
inmediatamente (ej. stock), una vista materializada no es el mecanismo
apropiado — se usaría la tabla base o una vista normal.

---

## Reproducibilidad

1. `createdb foodstore_plantilla` → `psql -f schema.sql` → `psql -f data.sql`
   → `ANALYZE`.
2. `createdb -T foodstore_plantilla foodstore_u3_tp` (copia de trabajo).
3. Capturar `EXPLAIN ANALYZE` **antes** → aplicar `indices.sql` → capturar
   **después**.
4. Aplicar `views.sql` y correr las verificaciones EXCEPT.
5. Aplicar `materializadas.sql` y medir original vs vista.

Comandos exactos y salidas crudas: `README.md` y `mediciones/`.