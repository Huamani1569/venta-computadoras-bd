-- OPCIONAL: ejecutar como administrador después de instalar.sql.
-- Crea un rol de grupo SIN LOGIN; no contiene contraseñas.
-- El administrador podrá conceder este rol a una cuenta de servicio.
-- No incluido en instalar.sql porque CREATE ROLE requiere privilegios especiales.
BEGIN;
CREATE ROLE ventas_app NOLOGIN;
GRANT USAGE ON SCHEMA tienda TO ventas_app;
GRANT SELECT ON ALL TABLES IN SCHEMA tienda TO ventas_app;
GRANT INSERT ON tienda.clientes,tienda.productos,tienda.proveedores,
    tienda.categorias,tienda.marcas,tienda.producto_proveedor TO ventas_app;
GRANT UPDATE (nombre_razon_social,correo,telefono,direccion,activo) ON tienda.clientes TO ventas_app;
GRANT UPDATE (sku,nombre,categoria_id,marca_id,procesador,ram_gb,almacenamiento_gb,
    tipo_almacenamiento,tarjeta_grafica,precio_venta,stock_minimo,activo)
    ON tienda.productos TO ventas_app;
GRANT UPDATE (razon_social,correo,telefono,direccion,activo) ON tienda.proveedores TO ventas_app;
GRANT USAGE, SELECT ON SEQUENCE tienda.clientes_cliente_id_seq,
    tienda.productos_producto_id_seq,tienda.proveedores_proveedor_id_seq,
    tienda.categorias_categoria_id_seq,tienda.marcas_marca_id_seq TO ventas_app;
GRANT EXECUTE ON FUNCTION tienda.registrar_venta(integer,text,jsonb) TO ventas_app;
GRANT EXECUTE ON FUNCTION tienda.anular_venta(integer,text) TO ventas_app;
COMMIT;
