# Contrato de rutas y mapeo de datos

**Estado:** diseño de API, sin servidor HTTP implementado. Prefijo `/api`. Las rutas definen cómo una futura capa backend accede a PostgreSQL; las tablas no atienden solicitudes HTTP por sí mismas. El contrato formal está en [openapi.yaml](openapi.yaml).

## Convenciones

- JSON UTF-8. IDs enteros positivos. Moneda PEN. Los precios se representan como cadenas decimales con dos posiciones para evitar pérdida de precisión al consumir JSON.
- Listados con `limit` (1..100, predeterminado 20) y `offset` (>=0, predeterminado 0), orden estable por ID ascendente. Respuesta: `{"items": [...], "limit":20, "offset":0}`. No se promete `total` de filas.
- Listas de productos, clientes y proveedores muestran activos por defecto; `activo=false` consulta solo inactivos. La consulta por ID devuelve el recurso aunque esté inactivo.
- `PATCH` modifica únicamente campos presentes y permitidos; no convierte campos omitidos en NULL. Productos, clientes y proveedores usan baja lógica con `DELETE`, sin borrar filas.
- Las ventas son inmutables después de registrarse. Se anulan con una operación específica. No existen `PUT /ventas`, `PATCH /ventas` ni `DELETE /ventas`.
- Todas las rutas pertenecen a una interfaz interna de gestión que requeriría autenticación. Crear/desactivar catálogo y clientes, consultar costos y anular ventas deben contar con autorización del backend. No hay autenticación implementada en este entregable.

## Inventario de rutas

| Método | Ruta | Acción | Tabla / operación | Éxito |
| --- | --- | --- | --- | --- |
| GET | `/api/categorias` | Listar categorías | SELECT categorias | 200 |
| GET | `/api/marcas` | Listar marcas | SELECT marcas | 200 |
| GET | `/api/productos` | Listar computadoras | SELECT productos + marcas + categorias | 200 |
| GET | `/api/productos/{id}` | Ver especificaciones | SELECT productos por PK | 200 |
| POST | `/api/productos` | Crear computadora y stock inicial | INSERT productos | 201 |
| PATCH | `/api/productos/{id}` | Actualizar catálogo sin cambiar stock | UPDATE columnas permitidas | 200 |
| DELETE | `/api/productos/{id}` | Desactivar computadora | UPDATE activo=false | 204 |
| GET | `/api/productos/{id}/proveedores` | Consultar suministradores/costos | JOIN producto_proveedor y proveedores | 200 |
| GET | `/api/clientes` | Listar clientes | SELECT clientes | 200 |
| GET | `/api/clientes/{id}` | Ver cliente | SELECT clientes por PK | 200 |
| POST | `/api/clientes` | Crear cliente | INSERT clientes | 201 |
| PATCH | `/api/clientes/{id}` | Modificar nombre/contacto/estado | UPDATE clientes | 200 |
| DELETE | `/api/clientes/{id}` | Desactivar cliente | UPDATE activo=false | 204 |
| GET | `/api/proveedores` | Listar proveedores | SELECT proveedores | 200 |
| POST | `/api/proveedores` | Crear proveedor | INSERT proveedores | 201 |
| GET | `/api/ventas` | Listar ventas históricas | SELECT v_ventas_resumen | 200 |
| GET | `/api/ventas/{id}` | Ver cabecera, total y detalles | v_ventas_resumen + detalle_venta | 200 |
| POST | `/api/ventas` | Registrar venta y descontar stock | registrar_venta | 201 |
| POST | `/api/ventas/{id}/anulacion` | Anular y devolver stock | anular_venta | 200 |
| GET | `/api/reportes/stock-bajo` | Ver alertas de existencias | SELECT v_stock_bajo | 200 |

Las asociaciones producto/proveedor y los catálogos de categorías/marcas se cargan mediante DML o administración SQL; no se inventa un CRUD completo para recursos que no lo requieren en esta actividad. El total de ventas se consulta con la vista, no con un valor enviado por el usuario.

## Registro de venta: ruta crítica

`POST /api/ventas`

Entrada:

```json
{
  "cliente_id": 1,
  "metodo_pago": "EFECTIVO",
  "detalles": [
    {"producto_id": 1, "cantidad": 1},
    {"producto_id": 3, "cantidad": 2}
  ]
}
```

El backend valida campos adicionales y rangos y ejecuta una llamada parametrizada:

```sql
SELECT tienda.registrar_venta($1::integer,$2::text,$3::jsonb) AS venta_id;
```

Mapeo: `$1=cliente_id`, `$2=metodo_pago`, `$3=detalles` serializado como JSON. Los placeholders son del driver PostgreSQL, no valores para pegar literalmente en pgAdmin.

Respuesta `201 Created` (ID ilustrativo; usar el devuelto por la base):

```json
{"venta_id":4,"estado":"CONFIRMADA","moneda":"PEN","total":"9000.00"}
```

Para responder con total/estado, consultar `v_ventas_resumen` por el ID devuelto en la misma transacción del backend. No confiar en `MAX(venta_id)` ni en el último ID global. No se incluye idempotencia de solicitudes HTTP; reintentar una venta después de perder una respuesta requeriría ampliar el contrato con una clave de idempotencia.

## Consulta de venta

`GET /api/ventas/{id}`:

```sql
SELECT r.*,c.nombre_razon_social FROM tienda.v_ventas_resumen r
JOIN tienda.clientes c USING(cliente_id) WHERE r.venta_id=$1;
SELECT d.producto_id,p.sku,p.nombre,d.cantidad,d.precio_unitario,d.subtotal
FROM tienda.detalle_venta d JOIN tienda.productos p USING(producto_id)
WHERE d.venta_id=$1 ORDER BY d.producto_id;
```

Respuesta de ejemplo para la venta inicial 1:

```json
{
  "venta_id":1,"cliente_id":1,"estado":"CONFIRMADA",
  "metodo_pago":"EFECTIVO","moneda":"PEN","total":"9000.00",
  "detalles":[
    {"producto_id":1,"cantidad":1,"precio_unitario":"3200.00","subtotal":"3200.00"},
    {"producto_id":3,"cantidad":2,"precio_unitario":"2900.00","subtotal":"5800.00"}
  ]
}
```

Los nombres actuales del catálogo se muestran para referencia; lo que se preserva históricamente es el precio y la cantidad. No se conserva una copia del nombre/descripción del producto en cada venta.

## Anulación

`POST /api/ventas/{id}/anulacion`, cuerpo `{"motivo":"Solicitud del cliente"}`:

```sql
SELECT tienda.anular_venta($1::integer,$2::text);
```

`$1` proviene de la ruta y `$2` del motivo. Respuesta `200`: `{"venta_id":1,"estado":"ANULADA"}`. Una segunda anulación devuelve `409`, sin reponer stock nuevamente.

## Mapeos restantes a SQL

Siempre parametrizar valores. El backend debe construir una lista permitida de columnas para PATCH, sin aceptar nombres de columnas arbitrarios. Las transacciones siguientes son sentencias individuales salvo el registro y consulta de venta.

```sql
-- GET /api/productos?activo=true&limit=20&offset=0
SELECT p.*,m.nombre AS marca,c.nombre AS categoria FROM tienda.productos p
JOIN tienda.marcas m USING(marca_id) JOIN tienda.categorias c USING(categoria_id)
WHERE p.activo=$1 ORDER BY p.producto_id LIMIT $2 OFFSET $3;
-- GET /api/productos/{id}
SELECT * FROM tienda.productos WHERE producto_id=$1;
-- POST /api/productos: nueve datos obligatorios + campos con defecto/opcionales.
INSERT INTO tienda.productos(sku,nombre,categoria_id,marca_id,procesador,ram_gb,
 almacenamiento_gb,tipo_almacenamiento,tarjeta_grafica,precio_venta,stock,stock_minimo,activo)
VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING *;
-- PATCH /api/productos/{id}: ejemplo si solo se recibe precio_venta.
UPDATE tienda.productos SET precio_venta=$2 WHERE producto_id=$1 RETURNING *;
-- DELETE /api/productos/{id}
UPDATE tienda.productos SET activo=false WHERE producto_id=$1 RETURNING producto_id;
-- GET /api/productos/{id}/proveedores: primero verificar que producto_id exista.
SELECT pr.proveedor_id,pr.razon_social,pp.costo_referencial
FROM tienda.producto_proveedor pp JOIN tienda.proveedores pr USING(proveedor_id)
WHERE pp.producto_id=$1 AND pr.activo ORDER BY pr.proveedor_id LIMIT $2 OFFSET $3;

-- GET /api/clientes
SELECT * FROM tienda.clientes WHERE activo=$1 ORDER BY cliente_id LIMIT $2 OFFSET $3;
-- GET /api/clientes/{id}
SELECT * FROM tienda.clientes WHERE cliente_id=$1;
-- POST /api/clientes
INSERT INTO tienda.clientes(tipo_documento,numero_documento,nombre_razon_social,correo,telefono,direccion)
VALUES($1,$2,$3,$4,$5,$6) RETURNING *;
-- PATCH /api/clientes/{id}: ejemplo de campo presente.
UPDATE tienda.clientes SET correo=$2 WHERE cliente_id=$1 RETURNING *;
-- DELETE /api/clientes/{id}
UPDATE tienda.clientes SET activo=false WHERE cliente_id=$1 RETURNING cliente_id;

-- GET /api/proveedores
SELECT * FROM tienda.proveedores WHERE activo=$1 ORDER BY proveedor_id LIMIT $2 OFFSET $3;
-- POST /api/proveedores
INSERT INTO tienda.proveedores(ruc,razon_social,correo,telefono,direccion)
VALUES($1,$2,$3,$4,$5) RETURNING *;
-- GET /api/categorias; GET /api/marcas (consultas independientes)
SELECT * FROM tienda.categorias ORDER BY categoria_id LIMIT $1 OFFSET $2;
SELECT * FROM tienda.marcas ORDER BY marca_id LIMIT $1 OFFSET $2;
-- GET /api/ventas (incluye anuladas)
SELECT * FROM tienda.v_ventas_resumen ORDER BY venta_id LIMIT $1 OFFSET $2;
-- GET /api/reportes/stock-bajo
SELECT * FROM tienda.v_stock_bajo ORDER BY producto_id LIMIT $1 OFFSET $2;
```

POST productos requiere nueve campos obligatorios (ver OpenAPI). Para los campos omitidos, el backend aplica `stock=0`, `stock_minimo=2`, `activo=true` y `tarjeta_grafica=NULL`. POST clientes/proveedores aplica `activo=true`. Los PATCH no admiten stock ni cambio de documento/RUC. Baja lógica repetida es idempotente (204); ID inexistente devuelve 404.

## Errores

Formato: `{"codigo":"STOCK_INSUFICIENTE","mensaje":"No hay unidades suficientes para el producto solicitado"}`.

| Situación | SQLSTATE / origen | HTTP propuesto |
| --- | --- | --- |
| JSON inválido, ID/rango incorrecto | Backend o 22023 | 400 |
| Cliente/producto/venta inexistente en ruta crítica | P0002 | 404 |
| Cliente inactivo al vender | P0002, mensaje de función | 404 (no disponible para venta) |
| Stock insuficiente, producto inactivo, ya anulada | P0001 | 409 |
| SKU/documento/RUC repetido | 23505 | 409 |
| FK inexistente al crear catálogo; CHECK/NOT NULL | 23503 / 23514 / 23502 | 422 |
| ID de consulta/PATCH/DELETE no encontrado | Cero filas | 404 |
| Error inesperado | Otros | 500, sin exponer detalles internos |

Las funciones comparten código de error para varios conflictos; el backend debe mapearlos a mensajes de negocio. Para una API de producción puede ampliarse a códigos propios diferenciados. Los fallos de serialización o interbloqueo (`40001`, `40P01`) requieren manejo transaccional del backend.
