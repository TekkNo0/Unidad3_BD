-- ============================================================
-- Proyecto integrador: FOOD STORE
-- schema.sql - Schema heredado de las Semanas 1 a 4 (Unidad 2)
-- Motor: PostgreSQL 17.x
-- NOTA: NO se modifica en la Semana 1 de la Unidad 3.
-- Esta entrega agrega unicamente objetos (indices y vistas)
-- sin alterar las tablas base ni sus restricciones.
-- ============================================================

-- Borrado defensivo al recrear el esquema desde cero.
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido       CASCADE;
DROP TABLE IF EXISTS usuario      CASCADE;
DROP TABLE IF EXISTS producto     CASCADE;
DROP TABLE IF EXISTS categoria    CASCADE;

-- ----------------------------------------------
-- Categorias de productos (vigencia = activo)
-- ----------------------------------------------
CREATE TABLE categoria (
    id     SERIAL PRIMARY KEY,
    nombre TEXT    NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------
-- Productos del catalogo
-- ----------------------------------------------
CREATE TABLE producto (
    id          SERIAL PRIMARY KEY,
    nombre      TEXT           NOT NULL,
    precio      NUMERIC(10,2)  NOT NULL CHECK (precio >= 0),
    categoria_id INT           NOT NULL REFERENCES categoria(id),
    activo      BOOLEAN        NOT NULL DEFAULT TRUE  -- vigencia del producto
);

-- ----------------------------------------------
-- Usuarios registrados en el sistema
-- ----------------------------------------------
CREATE TABLE usuario (
    id         SERIAL PRIMARY KEY,
    nombre     TEXT    NOT NULL,
    apellido   TEXT    NOT NULL,
    email      TEXT    NOT NULL UNIQUE,
    contrasena TEXT    NOT NULL,          -- columna protegida: no se expone en vistas
    activo     BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------
-- Pedidos realizados por un usuario
-- ----------------------------------------------
CREATE TABLE pedido (
    id         SERIAL PRIMARY KEY,
    usuario_id INT           NOT NULL REFERENCES usuario(id),
    fecha      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    total      NUMERIC(12,2) NOT NULL DEFAULT 0,
    estado     TEXT          NOT NULL DEFAULT 'PENDIENTE'
                  CHECK (estado IN ('PENDIENTE','CONFIRMADO','CANCELADO','ENTREGADO')),
    eliminado  BOOLEAN       NOT NULL DEFAULT FALSE  -- baja logica del pedido
);

-- ----------------------------------------------
-- Detalle (lineas) de cada pedido
-- ----------------------------------------------
CREATE TABLE detalle_pedido (
    id             SERIAL PRIMARY KEY,
    pedido_id      INT           NOT NULL REFERENCES pedido(id),
    producto_id    INT           NOT NULL REFERENCES producto(id),
    cantidad       INT           NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0)
);

-- ----------------------------------------------
-- Indices heredados de la Semana 3
--   - idx_producto_categoria  : FK producto -> categoria
--   - idx_pedido_usuario      : FK pedido -> usuario
--   - idx_producto_nombre_vig : busqueda por nombre de productos vigentes
-- ----------------------------------------------
CREATE INDEX idx_producto_categoria ON producto (categoria_id);

CREATE INDEX idx_pedido_usuario ON pedido (usuario_id);

CREATE INDEX idx_producto_nombre_vig
    ON producto (nombre)
    WHERE activo = TRUE;