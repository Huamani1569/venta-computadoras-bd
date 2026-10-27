-- PostgreSQL 16 o superior. Ejecutar en una base de datos nueva.
-- No elimina ni sobrescribe un esquema existente.
BEGIN;
CREATE SCHEMA tienda;
REVOKE ALL ON SCHEMA tienda FROM PUBLIC;

CREATE TABLE tienda.categorias (
    categoria_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre varchar(60) NOT NULL UNIQUE CHECK (btrim(nombre) <> ''),
    descripcion varchar(200)
);
CREATE TABLE tienda.marcas (
    marca_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre varchar(60) NOT NULL UNIQUE CHECK (btrim(nombre) <> '')
);
CREATE TABLE tienda.proveedores (
    proveedor_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ruc varchar(11) NOT NULL UNIQUE CHECK (ruc ~ '^[0-9]{11}$'),
    razon_social varchar(150) NOT NULL CHECK (btrim(razon_social) <> ''),
    correo varchar(150),
    telefono varchar(20),
    direccion varchar(200),
    activo boolean NOT NULL DEFAULT true
);
CREATE TABLE tienda.productos (
    producto_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku varchar(30) NOT NULL UNIQUE CHECK (btrim(sku) <> ''),
    nombre varchar(150) NOT NULL CHECK (btrim(nombre) <> ''),
    categoria_id integer NOT NULL REFERENCES tienda.categorias ON DELETE RESTRICT,
    marca_id integer NOT NULL REFERENCES tienda.marcas ON DELETE RESTRICT,
    procesador varchar(100) NOT NULL CHECK (btrim(procesador) <> ''),
    ram_gb smallint NOT NULL CHECK (ram_gb BETWEEN 1 AND 1024),
    almacenamiento_gb integer NOT NULL CHECK (almacenamiento_gb BETWEEN 1 AND 100000),
    tipo_almacenamiento varchar(5) NOT NULL CHECK (tipo_almacenamiento IN ('SSD','HDD')),
    tarjeta_grafica varchar(100),
    precio_venta numeric(12,2) NOT NULL CHECK (precio_venta > 0),
    stock integer NOT NULL DEFAULT 0 CHECK (stock BETWEEN 0 AND 1000000000),
    stock_minimo integer NOT NULL DEFAULT 2 CHECK (stock_minimo BETWEEN 0 AND 1000000000),
    activo boolean NOT NULL DEFAULT true
);
CREATE TABLE tienda.producto_proveedor (
    producto_id integer NOT NULL REFERENCES tienda.productos ON DELETE RESTRICT,
    proveedor_id integer NOT NULL REFERENCES tienda.proveedores ON DELETE RESTRICT,
    costo_referencial numeric(12,2) NOT NULL CHECK (costo_referencial > 0),
    PRIMARY KEY (producto_id, proveedor_id)
);
CREATE TABLE tienda.clientes (
    cliente_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_documento varchar(3) NOT NULL CHECK (tipo_documento IN ('DNI','RUC','CE')),
    numero_documento varchar(12) NOT NULL,
    nombre_razon_social varchar(150) NOT NULL CHECK (btrim(nombre_razon_social) <> ''),
    correo varchar(150),
    telefono varchar(20),
    direccion varchar(200),
    activo boolean NOT NULL DEFAULT true,
    UNIQUE (tipo_documento, numero_documento),
    CHECK ((tipo_documento = 'DNI' AND numero_documento ~ '^[0-9]{8}$')
        OR (tipo_documento = 'RUC' AND numero_documento ~ '^[0-9]{11}$')
        OR (tipo_documento = 'CE' AND numero_documento ~ '^[A-Za-z0-9]{9,12}$'))
);
CREATE TABLE tienda.ventas (
    venta_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id integer NOT NULL REFERENCES tienda.clientes ON DELETE RESTRICT,
    fecha timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado varchar(10) NOT NULL DEFAULT 'CONFIRMADA' CHECK (estado IN ('CONFIRMADA','ANULADA')),
    metodo_pago varchar(14) NOT NULL CHECK (metodo_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA')),
    moneda char(3) NOT NULL DEFAULT 'PEN' CHECK (moneda = 'PEN'),
    fecha_anulacion timestamptz,
    motivo_anulacion varchar(250),
    CHECK ((estado = 'CONFIRMADA' AND fecha_anulacion IS NULL AND motivo_anulacion IS NULL)
        OR (estado = 'ANULADA' AND fecha_anulacion IS NOT NULL
            AND motivo_anulacion IS NOT NULL AND btrim(motivo_anulacion) <> ''))
);
CREATE TABLE tienda.detalle_venta (
    venta_id integer NOT NULL REFERENCES tienda.ventas ON DELETE RESTRICT,
    producto_id integer NOT NULL REFERENCES tienda.productos ON DELETE RESTRICT,
    cantidad integer NOT NULL CHECK (cantidad BETWEEN 1 AND 1000),
    precio_unitario numeric(12,2) NOT NULL CHECK (precio_unitario > 0),
    subtotal numeric(16,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    PRIMARY KEY (venta_id, producto_id)
);

-- Las PK y UNIQUE crean sus índices automáticamente. Estos cubren FK y búsquedas.
CREATE INDEX ix_productos_categoria ON tienda.productos(categoria_id);
CREATE INDEX ix_productos_marca ON tienda.productos(marca_id);
CREATE INDEX ix_producto_proveedor_proveedor ON tienda.producto_proveedor(proveedor_id);
CREATE INDEX ix_ventas_cliente_fecha ON tienda.ventas(cliente_id, fecha DESC);
CREATE INDEX ix_ventas_fecha ON tienda.ventas(fecha);
CREATE INDEX ix_detalle_producto ON tienda.detalle_venta(producto_id);

-- El total no se duplica en la cabecera: se calcula desde los precios históricos.
CREATE VIEW tienda.v_ventas_resumen AS
SELECT v.venta_id, v.cliente_id, v.fecha, v.estado, v.metodo_pago, v.moneda,
       COALESCE(SUM(d.subtotal), 0)::numeric(18,2) AS total
FROM tienda.ventas v LEFT JOIN tienda.detalle_venta d USING (venta_id)
GROUP BY v.venta_id;
CREATE VIEW tienda.v_stock_bajo AS
SELECT producto_id, sku, nombre, stock, stock_minimo
FROM tienda.productos WHERE activo AND stock <= stock_minimo;
COMMIT;
