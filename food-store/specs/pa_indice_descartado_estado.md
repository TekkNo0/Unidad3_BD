# spec: pa_indice_descartado_estado

Herramienta: Kiro (especificacion previa) -> OpenCode (generacion)
Estado: DESCARTADO por sobreindexacion (se documenta como caso).

## Objetivo
En el marco de la Parte A se pidio a la IA proponer un indice
"generico" que acelerara el filtro por estado de un pedido.

## Consulta candidata
```sql
SELECT id, fecha, total FROM pedido WHERE estado = 'CONFIRMADO';
```

## Propuesta generada
`CREATE INDEX idx_pedido_estado ON pedido (estado);`

## Motivo del descarte
1. **Cardinalidad baja**: `estado` tiene 4 valores distintos
   (PENDIENTE/CONFIRMADO/CANCELADO/ENTREGADO). Filtrar por un estado
   solo deja ~50% (o menos) de las 200.000 filas; el optimizador no
   elige un Index Scan para eso (prefiere Seq Scan).
2. **Redundante**: la misma columna ya queda cubierta como segunda
   columna del indice aceptado `idx_pedido_fecha_estado_vig`; un
   indice `(estado)` separado agrega costo de mantenimiento en cada
   INSERT/UPDATE de `pedido` sin cambiar ningun plan.
3. La unica variante defendible (parcial, e.g. solo sobre un estado
   minoritario) tampoco aporta a la carga de trabajo real porque esas
   consultas no usan estado solo; usan fecha + estado.

## Criterio
Se aceptan indices si y solo si el plan real cambia y el tiempo baja;
este caso no cumple ni el requisito minimo, por lo que se descarta y
su justificacion queda en informe_mediciones.md.