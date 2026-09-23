# Food Store — Unidad 3, Semana 1: Índices, vistas y vistas materializadas

Trabajo Práctico de Base de Datos II sobre el proyecto integrador **Food
Store**. Esta semana agrega **índices y vistas** sobre el esquema heredado
(Semanas 1–4) **sin modificar las tablas base**.

Repositorio: https://github.com/TekkNo0/Unidad3_BD · carpeta `food-store/`

## Estructura del repositorio

```
food-store/
├── schema.sql            (heredado, sin modificar)
├── data.sql              (heredado, con volumen ampliado)
├── queries.sql           (heredado: carga de trabajo a indexar)
├── indices.sql           (NUEVO - Parte A: plan de indexado)
├── views.sql             (NUEVO - Parte B: vistas + seguridad)
├── materializadas.sql    (NUEVO - Parte C: vista materializada)
├── specs/                (especificaciones Kiro de cada pieza)
├── duia.md               (bitácora de uso de IA)
├── informe_mediciones.md (EXPLAIN ANALYZE antes/después, lectura y escritura)
├── mediciones/           (salidas crudas de EXPLAIN ANALYZE y mediciones)
└── backups/              (pg_dump previo al cambio estructural)
```

## Entorno

- PostgreSQL 17 (local, `localhost:5432`), cliente `psql`.
- Bins: `C:\Program Files\PostgreSQL\17\bin\`.

## Protocolo de seguridad (se sigue siempre)

1. **Copia**: se trabaja sobre `foodstore_u3_tp`, copia creada con
   `createdb -T foodstore_plantilla foodstore_u3_tp`. Nunca sobre la base
   canónica.
2. **Transacción**: cada script de escritura se aplica dentro de
   `BEGIN; …; COMMIT;` (reversible con `ROLLBACK`).
3. **Respaldo**: `pg_dump` antes de un cambio estructural (ver `backups/`,
   comprimido `.gz`).

## Reproducir las pruebas

```powershell
$env:PGPASSWORD="<password>"
$PSQL="C:\Program Files\PostgreSQL\17\bin\psql.exe"

# 1) Plantilla (schema + datos)
& $PSQL -h localhost -U postgres -c "DROP DATABASE IF EXISTS foodstore_plantilla;"
& $PSQL -h localhost -U postgres -c "CREATE DATABASE foodstore_plantilla;"
& $PSQL -h localhost -U postgres -d foodstore_plantilla -f schema.sql
& $PSQL -h localhost -U postgres -d foodstore_plantilla -f data.sql
& $PSQL -h localhost -U postgres -d foodstore_plantilla -c "ANALYZE;"

# 2) Copia de trabajo
& $PSQL -h localhost -U postgres -c "DROP DATABASE IF EXISTS foodstore_u3_tp;"
& $PSQL -h localhost -U postgres -c "CREATE DATABASE foodstore_u3_tp TEMPLATE foodstore_plantilla;"

# 3) Antes: EXPLAIN ANALYZE (Estado A) y carga de escritura
& $PSQL -h localhost -U postgres -d foodstore_u3_tp -c "EXPLAIN (ANALYZE, VERBOSE, BUFFERS) <QF1/QF2/QF3>"

# 4) Aplicar índices (Estado B) y repetir EXPLAIN ANALYZE
& $PSQL -h localhost -U postgres -d foodstore_u3_tp -f indices.sql

# 5) Vistas + verificación de equivalencia
& $PSQL -h localhost -U postgres -d foodstore_u3_tp -f views.sql
#   ... correr las 8 consultas EXCEPT (vista vs manual, ambas direcciones)

# 6) Vista materializada y mediciones
& $PSQL -h localhost -U postgres -d foodstore_u3_tp -f materializadas.sql
#   comparar tiempos: consulta original vs SELECT de la matview
```

## Consultas indexadas (Parte A)

| Consulta | Índice creado | Antes → Después |
|---|---|---|
| QF1 · pedidos CONFIRMADOS del mes | `idx_pedido_fecha_estado_vig` (btree compuesto parcial) | 51,6 ms → 6,2 ms |
| QF2 · historial de ventas de un producto | `idx_detalle_pedido_producto` (btree) | 147,5 ms → 0,5 ms |
| QF3 · búsqueda por nombre parcial | `idx_producto_nombre_trgm` (GIN pg_trgm parcial) | 39,2 ms → 3,0 ms |

Descartado por sobreindexación: `idx_pedido_estado` (cardinalidad baja +
redundante + costo de escritura) — ver `specs/` e `informe_mediciones.md`.

## Vistas (Parte B)

`v_productos_vigentes`, `v_pedidos_usuario`, `v_detalle_pedido_producto` y
`v_usuarios_sin_contrasena` (seguridad: no expone `contrasena`, con
`GRANT SELECT`). Las 4 verificadas equivalentes a su consulta manual con
`EXCEPT` = 0 filas.

## Vista materializada (Parte C)

`mv_facturacion_mensual_categoria` (facturación por categoría y mes) con
índice único `(anio, mes, categoria_id)` para `REFRESH CONCURRENTLY`.
Consulta: ~0,26 ms vs ~301 ms original (~1.000×). Refresco diario; entre
refrescos el reporte es una foto (no incluye pedidos nuevos).

## Pares clave del flujo con IA

spec → SQL:

- `specs/pa_indice_pedido_fecha_estado.md` → `indices.sql` (bloque 1)
- `specs/pa_indice_detalle_pedido_producto.md` → `indices.sql` (bloque 2)
- `specs/pa_indice_producto_nombre_trgm.md` → `indices.sql` (bloque 3)
- `specs/pa_indice_descartado_estado.md` → descartado, justificado en informe
- `specs/pb_vista_*.md` → `views.sql`
- `specs/pc_vista_materializada_facturacion.md` → `materializadas.sql`

Bitácora completa: `duia.md`.