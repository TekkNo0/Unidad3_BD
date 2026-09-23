# DUIA — Declaración de Uso de IA

Trabajo Práctico: Unidad 3, Semana 1 — Índices, vistas y vistas materializadas
(Food Store). Base de Datos II.

Regla del flujo: **especificar primero (Kiro) → generar después (OpenCode) →
leer línea por línea → probar en copia con transacción/backup → recién entonces
versionar**. La decisión nunca se delega: todo lo que la IA propuso fue
verificado contra el plan real (`EXPLAIN ANALYZE`) antes de aceptarse.

| # | Herramienta | Propósito | Prompt / spec | Propuesta de la IA | Decisión y justificación técnica |
|---|---|---|---|---|---|
| 1 | Kiro | Especificar el índice para el reporte mensual | `specs/pa_indice_pedido_fecha_estado.md` | Índice btree compuesto `(fecha, estado)` parcial `WHERE NOT eliminado` | **Aceptado**. El plan pasó de `Parallel Seq Scan` (51,6 ms) a `Bitmap Index Scan` (6,2 ms) (~8,4×). La parte parcial evita mantener filas eliminadas y el compuesto cubre fecha+estado. |
| 2 | Kiro | Especificar el índice para el historial de un producto | `specs/pa_indice_detalle_pedido_producto.md` | `CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido (producto_id)` | **Aceptado**. Se verificó que el join (Nested Loop por PK) era correcto y el cuello era el Seq Scan de 600k líneas. El plan pasó de 147,5 ms a 0,5 ms (~277×). |
| 3 | Kiro | Especificar el índice para búsqueda por nombre parcial | `specs/pa_indice_producto_nombre_trgm.md` | Extensión `pg_trgm` + `GIN (nombre gin_trgm_ops)` parcial `WHERE activo = TRUE` | **Aceptado**. Un btree (incluido el heredado `idx_producto_nombre_vig`) no resuelve `LIKE '%…%'`; el GIN pasa de `Seq Scan` (39,2 ms) a `Bitmap Index Scan` GIN (3,0 ms) (~13,3×). Se mantuvo el btree heredado para prefijos/orden. |
| 4 | OpenCode | Generar las sentencias `CREATE INDEX` desde las specs | iniciar con `CREATE EXTENSION IF NOT EXISTS pg_trgm;` y tres `CREATE INDEX` | — | Los tres `CREATE INDEX` se leyeron línea por línea y se aplicaron dentro de `BEGIN;…;COMMIT;` sobre la copia `foodstore_u3_tp`, con `pg_dump` previo en `backups/`. |
| 5 | Kiro | Propuesta genérica "acelera el filtro por estado" | `specs/pa_indice_descartado_estado.md` | `CREATE INDEX idx_pedido_estado ON pedido (estado)` | **DESCARTADO (sobreindexación)**. `estado` tiene 4 valores (cardinalidad baja); el optimizador no elige el índice. Es redundante con la col. 2 del compuesto aceptado e impone mantenimiento en escritura sin cambiar ningún plan. |
| 6 | Kiro | Especificar las vistas de reportes | `specs/pb_vista_*.md` (4 specs: productos vigentes, pedidos-usuario, detalle+producto, seguridad) | 4 vistas; la de seguridad expone `usuario` sin `contrasena` | **Aceptadas**. Verificación de equivalencia contra la consulta manual con `EXCEPT` en ambos sentidos = 0 filas para las 4 (`mediciones/verificacion_vistas.out`). `v_usuarios_sin_contrasena` permite `GRANT SELECT` sin acceso a la tabla base. |
| 7 | Kiro | Especificar la vista materializada de facturación | `specs/pc_vista_materializada_facturacion.md` | `CREATE MATERIALIZED VIEW ... WITH DATA` + índice único `(anio, mes, categoria_id)` | **Aceptado**. Consultar la matview cuesta ~0,26 ms vs ~301 ms de la consulta original (~1.000×). Construcción inicial: ~287 ms. Refresco diario con `REFRESH CONCURRENTLY` (habilita el índice único). |
| 8 | OpenCode | Medir siempre antes y después | textos literales de las 12 consultas de `queries.sql` con `EXPLAIN (ANALYZE, VERBOSE, BUFFERS)` | — | Cada medición quedó guardada en `mediciones/*.out`. Ninguna propuesta se aceptó sin el plan real que la justifique (misma regla de la Semana 3: solo se acepta lo que la medición posterior confirma). |

### Casos obligatorios mínimos

- **Sobreindexación descartada (Parte A):** `idx_pedido_estado` — ver fila 5 y
  `specs/pa_indice_descartado_estado.md`, `informe_mediciones.md` §Índice
  descartado. La decisión se tomó por cardinalidad baja + redundancia con el
  compuesto + costo de mantenimiento, no por intuición.
- **Equivalencia de vistas (Parte B):** las 4 vistas se verificaron contra su
  consulta manual con `EXCEPT` en ambos sentidos → 0 filas en los 8 cheques
  (fila 6 y `mediciones/verificacion_vistas.out`).

### Nota de ejecución responsable

Todos los scripts se ejecutaron sobre la **copia** `foodstore_u3_tp` (creada
por `createdb -T` desde la plantilla), nunca sobre la base canónica. Los
`CREATE INDEX`, las vistas y la vista materializada se aplicaron dentro de
`BEGIN;…;COMMIT;` (reversibles vía `ROLLBACK`), y se hizo `pg_dump` del estado
previo en `backups/foodstore_u3_tp_pre_indices_*.sql.gz` antes del primer cambio
estructural.