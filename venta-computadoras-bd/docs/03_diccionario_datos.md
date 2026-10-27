# Diccionario de datos

Esquema `tienda`: **8 tablas, 50 columnas**, 2 vistas y 2 funciones de negocio. Los tipos, longitudes, nulos y valores predeterminados se contrastaron con `information_schema` de una instalación ejecutada.

PK = clave primaria; FK = clave foránea; UQ = unicidad. `—` significa que no se define un valor predeterminado. Los campos NOT NULL deben recibir valor salvo que exista un predeterminado, identidad o expresión generada.

## categorias

| Campo | Tipo SQL | Nulo | Clave | Predeterminado / cálculo | Descripción y reglas |
| --- | --- | --- | --- | --- | --- |
| `categoria_id` | `integer` | No | PK | IDENTITY ALWAYS | Identificador de categoría. |
| `nombre` | `varchar(60)` | No | UQ | — | Nombre único y no vacío en catálogos; nombre no vacío de computadora en productos. |
| `descripcion` | `varchar(200)` | Sí | — | — | Descripción opcional de la categoría. |

## marcas

| Campo | Tipo SQL | Nulo | Clave | Predeterminado / cálculo | Descripción y reglas |
| --- | --- | --- | --- | --- | --- |
| `marca_id` | `integer` | No | PK | IDENTITY ALWAYS | Identificador de marca. |
| `nombre` | `varchar(60)` | No | UQ | — | Nombre único y no vacío en catálogos; nombre no vacío de computadora en productos. |

## proveedores

| Campo | Tipo SQL | Nulo | Clave | Predeterminado / cálculo | Descripción y reglas |
| --- | --- | --- | --- | --- | --- |
| `proveedor_id` | `integer` | No | PK | IDENTITY ALWAYS | Identificador de proveedor. |
| `ruc` | `varchar(11)` | No | UQ | — | Cadena única de 11 dígitos; validación de formato, no verificación tributaria. |
| `razon_social` | `varchar(150)` | No | — | — | Denominación del proveedor; no vacía. |
| `correo` | `varchar(150)` | Sí | — | — | Correo de contacto opcional; el DDL no comprueba entregabilidad ni formato. |
| `telefono` | `varchar(20)` | Sí | — | — | Teléfono de contacto, guardado como texto. |
| `direccion` | `varchar(200)` | Sí | — | — | Dirección de contacto opcional. |
| `activo` | `boolean` | No | — | true | Habilitado para las operaciones del negocio. |

## productos

| Campo | Tipo SQL | Nulo | Clave | Predeterminado / cálculo | Descripción y reglas |
| --- | --- | --- | --- | --- | --- |
| `producto_id` | `integer` | No | PK | IDENTITY ALWAYS | Identificador de configuración de computadora. |
| `sku` | `varchar(30)` | No | UQ | — | Código de configuración único y no vacío. |
| `nombre` | `varchar(150)` | No | — | — | Nombre único y no vacío en catálogos; nombre no vacío de computadora en productos. |
| `categoria_id` | `integer` | No | FK → categorias.categoria_id | — | Identificador de categoría. Referencia obligatoria; ON DELETE RESTRICT. |
| `marca_id` | `integer` | No | FK → marcas.marca_id | — | Identificador de marca. Referencia obligatoria; ON DELETE RESTRICT. |
| `procesador` | `varchar(100)` | No | — | — | Procesador de la configuración; no vacío. |
| `ram_gb` | `smallint` | No | — | — | Memoria RAM en GB: de 1 a 1024. |
| `almacenamiento_gb` | `integer` | No | — | — | Capacidad de almacenamiento en GB: de 1 a 100000. |
| `tipo_almacenamiento` | `varchar(5)` | No | — | — | SSD o HDD; una unidad principal por configuración. |
| `tarjeta_grafica` | `varchar(100)` | Sí | — | — | Modelo de GPU o texto Integrada; puede omitirse. |
| `precio_venta` | `numeric(12,2)` | No | — | — | Precio final actual en PEN, mayor que cero. |
| `stock` | `integer` | No | — | 0 | Unidades disponibles: 0 a 1000000000. Se modifica mediante venta/anulación. |
| `stock_minimo` | `integer` | No | — | 2 | Umbral de alerta: 0 a 1000000000. |
| `activo` | `boolean` | No | — | true | Habilitado para las operaciones del negocio. |

## producto_proveedor

| Campo | Tipo SQL | Nulo | Clave | Predeterminado / cálculo | Descripción y reglas |
| --- | --- | --- | --- | --- | --- |
| `producto_id` | `integer` | No | PK; FK → productos.producto_id | — | Identificador de configuración de computadora. Referencia obligatoria; ON DELETE RESTRICT. |
| `proveedor_id` | `integer` | No | PK; FK → proveedores.proveedor_id | — | Identificador de proveedor. Referencia obligatoria; ON DELETE RESTRICT. |
| `costo_referencial` | `numeric(12,2)` | No | — | — | Costo orientativo en PEN para el par producto/proveedor; mayor que cero. |

## clientes

| Campo | Tipo SQL | Nulo | Clave | Predeterminado / cálculo | Descripción y reglas |
| --- | --- | --- | --- | --- | --- |
| `cliente_id` | `integer` | No | PK | IDENTITY ALWAYS | Identificador de cliente. |
| `tipo_documento` | `varchar(3)` | No | UQ compuesta | — | DNI, RUC o CE. |
| `numero_documento` | `varchar(12)` | No | UQ compuesta | — | DNI: 8 dígitos; RUC: 11 dígitos; CE: 9 a 12 alfanuméricos. |
| `nombre_razon_social` | `varchar(150)` | No | — | — | Nombre de persona o empresa; no vacío. |
| `correo` | `varchar(150)` | Sí | — | — | Correo de contacto opcional; el DDL no comprueba entregabilidad ni formato. |
| `telefono` | `varchar(20)` | Sí | — | — | Teléfono de contacto, guardado como texto. |
| `direccion` | `varchar(200)` | Sí | — | — | Dirección de contacto opcional. |
| `activo` | `boolean` | No | — | true | Habilitado para las operaciones del negocio. |

## ventas

| Campo | Tipo SQL | Nulo | Clave | Predeterminado / cálculo | Descripción y reglas |
| --- | --- | --- | --- | --- | --- |
| `venta_id` | `integer` | No | PK | IDENTITY ALWAYS | Identificador interno de venta; no es numeración fiscal. |
| `cliente_id` | `integer` | No | FK → clientes.cliente_id | — | Identificador de cliente. Referencia obligatoria; ON DELETE RESTRICT. |
| `fecha` | `timestamptz` | No | — | CURRENT_TIMESTAMP | Instante de registro con zona horaria. |
| `estado` | `varchar(10)` | No | — | 'CONFIRMADA'::character varying | CONFIRMADA o ANULADA; coherente con datos de anulación. |
| `metodo_pago` | `varchar(14)` | No | — | — | EFECTIVO, TARJETA o TRANSFERENCIA. No hay pagos parciales. |
| `moneda` | `char(3)` | No | — | 'PEN'::bpchar | PEN exclusivamente. |
| `fecha_anulacion` | `timestamptz` | Sí | — | — | Instante de anulación; obligatorio solo cuando estado=ANULADA. |
| `motivo_anulacion` | `varchar(250)` | Sí | — | — | Texto no vacío si la venta está anulada; NULL si está confirmada. |

## detalle_venta

| Campo | Tipo SQL | Nulo | Clave | Predeterminado / cálculo | Descripción y reglas |
| --- | --- | --- | --- | --- | --- |
| `venta_id` | `integer` | No | PK; FK → ventas.venta_id | — | Identificador interno de venta; no es numeración fiscal. Referencia obligatoria; ON DELETE RESTRICT. |
| `producto_id` | `integer` | No | PK; FK → productos.producto_id | — | Identificador de configuración de computadora. Referencia obligatoria; ON DELETE RESTRICT. |
| `cantidad` | `integer` | No | — | — | Entero de 1 a 1000 por línea. |
| `precio_unitario` | `numeric(12,2)` | No | — | — | Precio de catálogo capturado al vender, positivo y conservado como histórico. |
| `subtotal` | `numeric(16,2)` | Sí | — | GENERATED ALWAYS (cantidad × precio_unitario) | Cantidad × precio_unitario; columna generada, no acepta escritura manual. |

## Restricciones de tabla

| Tabla | Restricción adicional |
| --- | --- |
| producto_proveedor | PK(producto_id, proveedor_id): no duplicar un suministro |
| detalle_venta | PK(venta_id, producto_id): una línea por producto y venta |
| clientes | UNIQUE(tipo_documento, numero_documento), CHECK de longitud/formato según tipo |
| ventas | CONFIRMADA exige fecha_anulacion y motivo_anulacion nulos; ANULADA exige ambos presentes y motivo no vacío |

## Vistas

| Vista | Columnas de salida |
| --- | --- |
| v_ventas_resumen | venta_id, cliente_id, fecha, estado, metodo_pago, moneda, total numeric(18,2) |
| v_stock_bajo | producto_id, sku, nombre, stock, stock_minimo |

## Funciones de negocio

| Función | Parámetros | Retorno | Efecto |
| --- | --- | --- | --- |
| registrar_venta | p_cliente_id integer, p_metodo_pago text, p_detalles jsonb | integer | Crea venta/detalles y descuenta stock atómicamente |
| anular_venta | p_venta_id integer, p_motivo text | void | Marca anulación y devuelve stock una sola vez |

La vista de resumen no persiste el total y no filtra ventas anuladas. Los índices y todas las restricciones ejecutables están en `database/01_ddl.sql`. Las reglas entre varias filas se aplican mediante funciones y permisos, no mediante CHECK.
