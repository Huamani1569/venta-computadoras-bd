-- Datos completamente ficticios para una instalación nueva; no reejecutar.
BEGIN;
INSERT INTO tienda.categorias(nombre, descripcion) VALUES
('Laptop','Computadora portátil'), ('Escritorio','Computadora de escritorio completa');
INSERT INTO tienda.marcas(nombre) VALUES ('Lenovo'),('ASUS'),('HP'),('Dell');
INSERT INTO tienda.proveedores(ruc, razon_social, correo, telefono, direccion) VALUES
('20000000001','Distribuidora Andina Demo SAC','ventas@andina.example','000000001','Dirección ficticia 1'),
('20000000002','Tecnología Sur Demo SAC','ventas@sur.example','000000002','Dirección ficticia 2'),
('20000000003','Importaciones Digitales Demo SAC','ventas@digital.example','000000003','Dirección ficticia 3');
INSERT INTO tienda.productos(sku,nombre,categoria_id,marca_id,procesador,ram_gb,
 almacenamiento_gb,tipo_almacenamiento,tarjeta_grafica,precio_venta,stock,stock_minimo) VALUES
('LAP-LEN-001','Lenovo LOQ Demo',1,1,'Intel Core i5',16,512,'SSD','NVIDIA RTX 3050',3200.00,10,2),
('LAP-ASU-001','ASUS TUF Demo',1,2,'Intel Core i7',16,1024,'SSD','NVIDIA RTX 4060',4800.00,8,2),
('LAP-HP-001','HP ProBook Demo',1,3,'Intel Core i5',16,512,'SSD','Integrada',2900.00,12,3),
('PC-DEL-001','Dell Oficina Demo',2,4,'Intel Core i5',8,512,'SSD','Integrada',2300.00,7,2),
('PC-ASU-001','ASUS Gamer Demo',2,2,'AMD Ryzen 7',32,1024,'SSD','NVIDIA RTX 4070',6500.00,5,2),
('LAP-LEN-002','Lenovo IdeaPad Demo',1,1,'AMD Ryzen 5',8,512,'SSD','Integrada',2200.00,2,2);
INSERT INTO tienda.producto_proveedor VALUES
(1,1,2700.00),(1,2,2750.00),(2,2,4100.00),(3,1,2400.00),
(4,3,1900.00),(5,2,5600.00),(5,3,5650.00),(6,1,1800.00);
INSERT INTO tienda.clientes(tipo_documento,numero_documento,nombre_razon_social,correo) VALUES
('DNI','00000001','Cliente Demostración Uno','cliente1@example.com'),
('DNI','00000002','Cliente Demostración Dos','cliente2@example.com'),
('RUC','20000000004','Empresa Demostración SAC','empresa@example.com'),
('CE','DEMO00001','Cliente Demostración Extranjero','cliente4@example.com');
SELECT tienda.registrar_venta(1,'EFECTIVO','[{"producto_id":1,"cantidad":1},{"producto_id":3,"cantidad":2}]');
SELECT tienda.registrar_venta(3,'TRANSFERENCIA','[{"producto_id":4,"cantidad":2}]');
SELECT tienda.registrar_venta(2,'TARJETA','[{"producto_id":2,"cantidad":1}]');
SELECT tienda.anular_venta(3,'Anulación de demostración por solicitud del cliente');
COMMIT;
