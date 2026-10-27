-- Rutinas transaccionales. SECURITY DEFINER permite conceder ejecución sin
-- autorizar escrituras directas en ventas, detalle_venta ni stock.
BEGIN;
CREATE FUNCTION tienda.registrar_venta(
    p_cliente_id integer, p_metodo_pago text, p_detalles jsonb
) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, tienda
AS $$
DECLARE
    v_item jsonb;
    v_linea record;
    v_producto tienda.productos%ROWTYPE;
    v_id integer;
BEGIN
    IF p_metodo_pago IS NULL OR p_metodo_pago NOT IN ('EFECTIVO','TARJETA','TRANSFERENCIA') THEN
        RAISE EXCEPTION 'Método de pago inválido' USING ERRCODE = '22023';
    END IF;
    IF p_detalles IS NULL OR jsonb_typeof(p_detalles) <> 'array' THEN
        RAISE EXCEPTION 'detalles debe ser un arreglo JSON' USING ERRCODE = '22023';
    END IF;
    IF jsonb_array_length(p_detalles) NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'La venta requiere entre 1 y 100 productos' USING ERRCODE = '22023';
    END IF;
    -- Validar antes de convertir, incluidos nulos, fracciones y campos inesperados.
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_detalles) LOOP
        IF jsonb_typeof(v_item) <> 'object' THEN
            RAISE EXCEPTION 'Cada detalle debe ser un objeto' USING ERRCODE = '22023';
        END IF;
        IF NOT (v_item ? 'producto_id' AND v_item ? 'cantidad')
           OR EXISTS (SELECT 1 FROM jsonb_object_keys(v_item) k
                      WHERE k NOT IN ('producto_id','cantidad')) THEN
            RAISE EXCEPTION 'Solo se admiten producto_id y cantidad' USING ERRCODE = '22023';
        END IF;
        IF jsonb_typeof(v_item->'producto_id') <> 'number'
           OR jsonb_typeof(v_item->'cantidad') <> 'number'
           OR (v_item->>'producto_id') !~ '^[1-9][0-9]*$'
           OR (v_item->>'cantidad') !~ '^[1-9][0-9]*$'
           OR v_item->>'producto_id' IS NULL OR v_item->>'cantidad' IS NULL THEN
            RAISE EXCEPTION 'ID y cantidad deben ser enteros positivos' USING ERRCODE = '22023';
        END IF;
        IF (v_item->>'producto_id')::numeric > 2147483647
           OR (v_item->>'cantidad')::numeric > 1000 THEN
            RAISE EXCEPTION 'ID o cantidad fuera de rango' USING ERRCODE = '22023';
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM jsonb_to_recordset(p_detalles) AS x(producto_id integer, cantidad integer)
               GROUP BY producto_id HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION 'No se permiten productos repetidos' USING ERRCODE = '22023';
    END IF;
    -- Evita una desactivación del cliente durante la transacción.
    PERFORM cliente_id FROM tienda.clientes WHERE cliente_id = p_cliente_id AND activo FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente inexistente o inactivo' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO tienda.ventas(cliente_id, metodo_pago)
    VALUES (p_cliente_id, p_metodo_pago) RETURNING venta_id INTO v_id;
    -- Orden estable de bloqueos entre ventas para reducir interbloqueos.
    FOR v_linea IN
        SELECT * FROM jsonb_to_recordset(p_detalles) AS x(producto_id integer, cantidad integer)
        ORDER BY producto_id
    LOOP
        SELECT * INTO v_producto FROM tienda.productos
        WHERE producto_id = v_linea.producto_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto % inexistente', v_linea.producto_id USING ERRCODE = 'P0002';
        END IF;
        IF NOT v_producto.activo OR v_producto.stock < v_linea.cantidad THEN
            RAISE EXCEPTION 'Producto % inactivo o stock insuficiente', v_linea.producto_id
                USING ERRCODE = 'P0001';
        END IF;
        INSERT INTO tienda.detalle_venta(venta_id, producto_id, cantidad, precio_unitario)
        VALUES (v_id, v_linea.producto_id, v_linea.cantidad, v_producto.precio_venta);
        UPDATE tienda.productos SET stock = stock - v_linea.cantidad
        WHERE producto_id = v_linea.producto_id;
    END LOOP;
    RETURN v_id;
END;
$$;

CREATE FUNCTION tienda.anular_venta(p_venta_id integer, p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, tienda
AS $$
DECLARE
    v_estado text;
    v_linea record;
BEGIN
    IF p_motivo IS NULL OR btrim(p_motivo) = '' OR length(p_motivo) > 250 THEN
        RAISE EXCEPTION 'Motivo requerido, máximo 250 caracteres' USING ERRCODE = '22023';
    END IF;
    SELECT estado INTO v_estado FROM tienda.ventas WHERE venta_id = p_venta_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venta inexistente' USING ERRCODE = 'P0002';
    END IF;
    IF v_estado = 'ANULADA' THEN
        RAISE EXCEPTION 'Venta ya anulada' USING ERRCODE = 'P0001';
    END IF;
    FOR v_linea IN SELECT producto_id, cantidad FROM tienda.detalle_venta
                   WHERE venta_id = p_venta_id ORDER BY producto_id LOOP
        UPDATE tienda.productos SET stock = stock + v_linea.cantidad
        WHERE producto_id = v_linea.producto_id;
    END LOOP;
    UPDATE tienda.ventas SET estado = 'ANULADA', fecha_anulacion = CURRENT_TIMESTAMP,
                            motivo_anulacion = btrim(p_motivo)
    WHERE venta_id = p_venta_id;
END;
$$;
REVOKE ALL ON FUNCTION tienda.registrar_venta(integer,text,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION tienda.anular_venta(integer,text) FROM PUBLIC;
COMMIT;
