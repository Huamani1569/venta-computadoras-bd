# Reglas, transacciones y seguridad

## Reglas del negocio

1. Un SKU identifica una configuración de computadora. RAM y capacidad de almacenamiento son positivas y tienen unidad explícita.
2. El documento del cliente es único por tipo. Se valida su formato, no su existencia ante una entidad externa. Los RUC de proveedores también tienen validación de formato solamente.
3. Los precios y costos son positivos. Stock y stock mínimo nunca son negativos.
4. Una venta acepta entre 1 y 100 productos distintos; la cantidad por línea es un entero de 1 a 1000. Para repetir un producto, el solicitante debe consolidarlo en una sola línea.
5. Solo se vende a clientes activos y con productos activos y suficientes existencias.
6. La entrada no acepta precios ni subtotales. El precio se lee de la base al registrar y se conserva en el detalle.
7. Registrar una venta implica guardar cabecera, líneas y descuento de stock. Si falla cualquier línea, no queda ningún cambio de esa llamada.
8. La anulación es total, exige motivo, conserva las líneas y repone stock una sola vez. No se eliminan ventas ni se editan sus detalles.
9. Los reportes de ventas efectivas excluyen `ANULADA`, aunque el importe histórico sigue visible.
10. `producto_proveedor` es un catálogo de suministro con costo referencial; no representa una compra ni un ingreso de almacén. El stock inicial se carga al crear el producto; la reposición posterior requiere ampliar el modelo con compras/kardex.

## Registrar venta

`tienda.registrar_venta(integer, text, jsonb) → integer`

1. Validar medio de pago y estructura JSON: objetos, claves admitidas, tipos, rango y duplicados.
2. Verificar cliente activo con `FOR SHARE`.
3. Crear la cabecera dentro de la misma transacción.
4. Procesar IDs de productos en orden ascendente y bloquear cada fila con `FOR UPDATE`.
5. Validar estado y stock del producto bloqueado.
6. Insertar cantidad y precio leído, descontar stock y devolver ID de venta.

Dos ventas concurrentes del mismo producto no deberían consumir el mismo saldo: la segunda espera el bloqueo y valida las existencias después. El orden ascendente reduce interbloqueos. En niveles de aislamiento que produzcan fallos de serialización, el backend debe gestionar el reintento completo de la transacción; no hay backend implementado aquí. La prueba real con dos sesiones está descrita en [validación](05_validacion.md).

## Anular venta

`tienda.anular_venta(integer, text) → void`

Se bloquea la cabecera de la venta, se rechaza una segunda anulación, se devuelven existencias en orden de ID y se registra fecha/motivo. Un error revierte también cualquier stock ya repuesto. La fila de venta serializa solicitudes simultáneas de anulación del mismo ID.

## Transacciones y llamadas

Las funciones no hacen `COMMIT` interno. PostgreSQL ejecuta cada llamada dentro de la transacción del cliente. En autocommit una llamada exitosa se confirma; con `BEGIN` explícito, el llamador controla el final. Ante una excepción, el cliente debe ejecutar `ROLLBACK` si mantiene una transacción abierta.

El rol propietario siempre puede saltarse las rutinas. Por eso una aplicación futura debe usar un rol de privilegios limitados. Las secuencias pueden presentar huecos tras una transacción fallida o una prueba; no se usan como numeración fiscal.

## Permisos opcionales

`database/06_permisos_opcionales.sql` crea el grupo `ventas_app` sin login ni contraseña. Es un paso administrativo opcional que se ejecuta una sola vez. Puede asignarse a una cuenta de servicio configurada por el administrador. No ejecutar la aplicación con la cuenta propietaria.

El grupo puede consultar el esquema, mantener datos permitidos del catálogo y clientes, y ejecutar las funciones. No puede actualizar stock directamente, escribir ventas/detalles ni borrar datos. Puede establecer stock inicial al insertar un producto; cambiar ese saldo después requiere un flujo de inventario fuera del alcance.

Las funciones usan `SECURITY DEFINER`, nombres de tablas cualificados, `search_path` fijo y permiso `EXECUTE` revocado a `PUBLIC`. El esquema no debe permitir que usuarios no confiables creen objetos. El propietario de las rutinas debe ser una cuenta administrativa confiable; en un despliegue real se recomienda que no sea superusuario.

Este rol SQL no sustituye autenticación o autorización HTTP. El backend futuro debe usar consultas parametrizadas, validar JSON y limitar las operaciones de administración a usuarios autorizados. No se incluyen contraseñas, claves de acceso ni datos de personas reales.
