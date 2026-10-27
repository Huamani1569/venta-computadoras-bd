-- Ejecutar sobre los datos de demostración SIN modificar.
-- Todas las modificaciones se revierten. Las secuencias pueden avanzar.
BEGIN;
CREATE TEMP TABLE resultados_pruebas(caso text PRIMARY KEY) ON COMMIT DROP;
CREATE FUNCTION pg_temp.verificar(p_ok boolean,p_etiqueta text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
    IF p_ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO: %',p_etiqueta; END IF;
    INSERT INTO resultados_pruebas VALUES (p_etiqueta);
    RAISE NOTICE 'OK: %',p_etiqueta;
END $$;
CREATE FUNCTION pg_temp.esperar_error(p_sql text,p_codigo text,p_etiqueta text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE v_codigo text;
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_codigo=RETURNED_SQLSTATE;
        IF v_codigo <> p_codigo THEN
            RAISE EXCEPTION 'FALLO: %, se esperaba % y se obtuvo %',p_etiqueta,p_codigo,v_codigo;
        END IF;
        INSERT INTO resultados_pruebas VALUES (p_etiqueta);
        RAISE NOTICE 'OK: %',p_etiqueta;
        RETURN;
    END;
    RAISE EXCEPTION 'FALLO: % no rechazó la operación',p_etiqueta;
END $$;

SELECT pg_temp.verificar((SELECT count(*)=8 FROM information_schema.tables
    WHERE table_schema='tienda' AND table_type='BASE TABLE'),'8 tablas creadas');
SELECT pg_temp.verificar((SELECT count(*)=6 FROM tienda.productos),'6 computadoras de prueba');
SELECT pg_temp.verificar((SELECT total=9000 FROM tienda.v_ventas_resumen WHERE venta_id=1),'total venta 1');
SELECT pg_temp.verificar((SELECT total=4600 FROM tienda.v_ventas_resumen WHERE venta_id=2),'total venta 2');
SELECT pg_temp.verificar((SELECT sum(total)=13600 FROM tienda.v_ventas_resumen
    WHERE estado='CONFIRMADA'),'reporte excluye anuladas');
SELECT pg_temp.verificar((SELECT array_agg(stock ORDER BY producto_id)=ARRAY[9,8,10,5,5,2]
    FROM tienda.productos),'stock inicial tras ventas y anulación');
SELECT pg_temp.verificar((SELECT count(*)=1 FROM tienda.v_stock_bajo),'alerta de stock');

DO $$ DECLARE v_id integer; v_total numeric; BEGIN
    v_id := tienda.registrar_venta(1,'TARJETA','[{"producto_id":1,"cantidad":2}]');
    PERFORM pg_temp.verificar((SELECT stock=7 FROM tienda.productos WHERE producto_id=1),'descuento de stock');
    SELECT total INTO v_total FROM tienda.v_ventas_resumen WHERE venta_id=v_id;
    PERFORM pg_temp.verificar(v_total=6400,'total calculado de nueva venta');
    UPDATE tienda.productos SET precio_venta=3300 WHERE producto_id=1;
    PERFORM pg_temp.verificar((SELECT total=6400 FROM tienda.v_ventas_resumen WHERE venta_id=v_id),
        'precio histórico no cambia');
    PERFORM tienda.anular_venta(v_id,'Prueba de devolución');
    PERFORM pg_temp.verificar((SELECT stock=9 FROM tienda.productos WHERE producto_id=1),'anulación restaura stock');
    PERFORM pg_temp.verificar((SELECT estado='ANULADA' AND fecha_anulacion IS NOT NULL
        FROM tienda.ventas WHERE venta_id=v_id),'anulación registra trazabilidad');
    PERFORM pg_temp.esperar_error(format('SELECT tienda.anular_venta(%s,%L)',v_id,'Otra vez'),
        'P0001','doble anulación rechazada');
    PERFORM pg_temp.verificar((SELECT stock=9 FROM tienda.productos WHERE producto_id=1),
        'doble anulación no duplica stock');
    UPDATE tienda.productos SET precio_venta=3200 WHERE producto_id=1;
END $$;

-- Un fallo en una segunda línea debe revertir también la primera y la cabecera.
DO $$ DECLARE v_ventas bigint; v_detalles bigint; BEGIN
    SELECT count(*) INTO v_ventas FROM tienda.ventas;
    SELECT count(*) INTO v_detalles FROM tienda.detalle_venta;
    PERFORM pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
        '[{"producto_id":1,"cantidad":1},{"producto_id":2,"cantidad":1000}]')$q$,
        'P0001','stock insuficiente rechazado');
    PERFORM pg_temp.verificar((SELECT count(*)=v_ventas FROM tienda.ventas),'rollback de cabecera');
    PERFORM pg_temp.verificar((SELECT count(*)=v_detalles FROM tienda.detalle_venta),'rollback de detalles');
    PERFORM pg_temp.verificar((SELECT stock=9 FROM tienda.productos WHERE producto_id=1),'rollback de stock previo');
END $$;

SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(999,'EFECTIVO',
    '[{"producto_id":1,"cantidad":1}]')$q$,'P0002','cliente inexistente');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":999,"cantidad":1}]')$q$,'P0002','producto inexistente');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'OTRO',
    '[{"producto_id":1,"cantidad":1}]')$q$,'22023','método inválido');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO','[]')$q$,'22023','venta vacía');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO','{}')$q$,'22023','JSON no arreglo');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',NULL)$q$,'22023','JSON SQL NULL');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO','[null]')$q$,'22023','detalle no objeto');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":1,"cantidad":0}]')$q$,'22023','cantidad cero');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":1,"cantidad":-1}]')$q$,'22023','cantidad negativa');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":1,"cantidad":1.5}]')$q$,'22023','cantidad fraccionaria');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":1,"cantidad":null}]')$q$,'22023','cantidad nula');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":1}]')$q$,'22023','cantidad ausente');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":"1","cantidad":1}]')$q$,'22023','ID de tipo texto');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":2147483648,"cantidad":1}]')$q$,'22023','ID fuera de rango');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":1,"cantidad":1001}]')$q$,'22023','cantidad fuera de rango');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":1,"cantidad":1,"precio_unitario":1}]')$q$,'22023','precio enviado por cliente rechazado');
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":1,"cantidad":1},{"producto_id":1,"cantidad":2}]')$q$,'22023','producto duplicado');
UPDATE tienda.clientes SET activo=false WHERE cliente_id=4;
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(4,'EFECTIVO',
    '[{"producto_id":1,"cantidad":1}]')$q$,'P0002','cliente inactivo');
UPDATE tienda.productos SET activo=false WHERE producto_id=6;
SELECT pg_temp.esperar_error($q$SELECT tienda.registrar_venta(1,'EFECTIVO',
    '[{"producto_id":6,"cantidad":1}]')$q$,'P0001','producto inactivo');
SELECT pg_temp.esperar_error($q$SELECT tienda.anular_venta(999,'Prueba')$q$,'P0002','anulación inexistente');
SELECT pg_temp.esperar_error($q$SELECT tienda.anular_venta(1,' ')$q$,'22023','motivo vacío');
SELECT pg_temp.esperar_error($q$UPDATE tienda.productos SET stock=-1 WHERE producto_id=1$q$,
    '23514','restricción stock no negativo');
SELECT pg_temp.esperar_error($q$UPDATE tienda.productos SET precio_venta=0 WHERE producto_id=1$q$,
    '23514','restricción precio positivo');
SELECT pg_temp.esperar_error($q$INSERT INTO tienda.clientes(tipo_documento,numero_documento,nombre_razon_social)
    VALUES('DNI','123','Demo')$q$,'23514','formato de documento');
SELECT pg_temp.esperar_error($q$UPDATE tienda.productos SET marca_id=999 WHERE producto_id=1$q$,
    '23503','integridad referencial');
SELECT pg_temp.esperar_error($q$UPDATE tienda.productos SET sku='LAP-LEN-001' WHERE producto_id=2$q$,
    '23505','SKU único');
SELECT pg_temp.esperar_error($q$DELETE FROM tienda.clientes WHERE cliente_id=1$q$,
    '23001','no borrar cliente con ventas');
SELECT pg_temp.esperar_error($q$DELETE FROM tienda.productos WHERE producto_id=1$q$,
    '23001','no borrar producto referenciado');
SELECT count(*) AS pruebas_correctas FROM resultados_pruebas;
ROLLBACK;
