-- Ejecutar como administrador después de 06_permisos_opcionales.sql.
-- Comprueba el rol ventas_app y revierte la venta de prueba.
BEGIN;
SET LOCAL ROLE ventas_app;
DO $$
DECLARE v_sql text; v_denegado boolean;
BEGIN
    FOREACH v_sql IN ARRAY ARRAY[
        'UPDATE tienda.productos SET stock=100 WHERE producto_id=1',
        'INSERT INTO tienda.ventas(cliente_id,metodo_pago) VALUES(1,''EFECTIVO'')',
        'UPDATE tienda.detalle_venta SET cantidad=3 WHERE venta_id=1'
    ] LOOP
        v_denegado := false;
        BEGIN
            EXECUTE v_sql;
        EXCEPTION WHEN insufficient_privilege THEN
            v_denegado := true;
        END;
        IF NOT v_denegado THEN RAISE EXCEPTION 'FALLO: permiso de escritura excesivo'; END IF;
        RAISE NOTICE 'OK: escritura directa bloqueada';
    END LOOP;
    PERFORM tienda.registrar_venta(1,'EFECTIVO','[{"producto_id":1,"cantidad":1}]');
    RAISE NOTICE 'OK: registro de venta permitido mediante función';
END $$;
SELECT 4 AS permisos_correctos;
ROLLBACK;
