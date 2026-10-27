-- Consultas de solo lectura; ejecutar después de instalar.sql.
-- 1. Catálogo: GET /api/productos
SELECT p.producto_id,p.sku,p.nombre,m.nombre AS marca,c.nombre AS categoria,
       p.procesador,p.ram_gb,p.almacenamiento_gb,p.tipo_almacenamiento,
       p.tarjeta_grafica,p.precio_venta,p.stock
FROM tienda.productos p JOIN tienda.marcas m USING(marca_id)
JOIN tienda.categorias c USING(categoria_id)
WHERE p.activo ORDER BY p.producto_id LIMIT 20 OFFSET 0;

-- 2. Cabecera y total de una venta: GET /api/ventas/1
SELECT r.*,c.nombre_razon_social FROM tienda.v_ventas_resumen r
JOIN tienda.clientes c USING(cliente_id) WHERE r.venta_id=1;
-- 3. Líneas de esa venta
SELECT d.*,p.sku,p.nombre FROM tienda.detalle_venta d
JOIN tienda.productos p USING(producto_id) WHERE d.venta_id=1 ORDER BY d.producto_id;

-- 4. Historial de un cliente
SELECT * FROM tienda.v_ventas_resumen WHERE cliente_id=1 ORDER BY fecha DESC,venta_id DESC;
-- 5. Stock bajo
SELECT * FROM tienda.v_stock_bajo ORDER BY stock,producto_id;
-- 6. Proveedores de una computadora
SELECT pr.proveedor_id,pr.razon_social,pp.costo_referencial
FROM tienda.producto_proveedor pp JOIN tienda.proveedores pr USING(proveedor_id)
WHERE pp.producto_id=1 AND pr.activo ORDER BY pp.costo_referencial;
-- 7. Ventas confirmadas por mes; mes definido en horario de Lima.
SELECT date_trunc('month',fecha AT TIME ZONE 'America/Lima')::date AS mes,
       count(*) AS cantidad_ventas,sum(total) AS importe_pen
FROM tienda.v_ventas_resumen WHERE estado='CONFIRMADA' GROUP BY 1 ORDER BY 1;
-- 8. Ranking de productos; excluye ventas anuladas.
SELECT p.producto_id,p.nombre,sum(d.cantidad) AS unidades,sum(d.subtotal) AS importe_pen
FROM tienda.detalle_venta d JOIN tienda.ventas v USING(venta_id)
JOIN tienda.productos p USING(producto_id) WHERE v.estado='CONFIRMADA'
GROUP BY p.producto_id ORDER BY unidades DESC,p.producto_id;
