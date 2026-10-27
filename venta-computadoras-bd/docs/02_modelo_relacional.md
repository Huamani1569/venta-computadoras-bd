# Modelo relacional y físico

## Relaciones

Notación: PK = clave primaria; FK = clave foránea; UQ = clave alternativa única. El diccionario detalla todos los campos y dominios.

```text
CATEGORIAS(categoria_id PK, nombre UQ, descripcion)
MARCAS(marca_id PK, nombre UQ)
PROVEEDORES(proveedor_id PK, ruc UQ, razon_social, correo, telefono, direccion, activo)
PRODUCTOS(producto_id PK, sku UQ, nombre, categoria_id FK, marca_id FK,
          procesador, ram_gb, almacenamiento_gb, tipo_almacenamiento,
          tarjeta_grafica, precio_venta, stock, stock_minimo, activo)
PRODUCTO_PROVEEDOR(producto_id PK/FK, proveedor_id PK/FK, costo_referencial)
CLIENTES(cliente_id PK, tipo_documento, numero_documento, nombre_razon_social,
         correo, telefono, direccion, activo; UQ(tipo_documento,numero_documento))
VENTAS(venta_id PK, cliente_id FK, fecha, estado, metodo_pago, moneda,
       fecha_anulacion, motivo_anulacion)
DETALLE_VENTA(venta_id PK/FK, producto_id PK/FK, cantidad, precio_unitario, subtotal)
```

![Modelo relacional](diagramas/modelo_relacional.png)

Editables: [SVG](diagramas/modelo_relacional.svg), [Mermaid](diagramas/modelo_relacional.mmd).

## Correspondencia de claves

| FK | Destino | Borrado |
| --- | --- | --- |
| productos.categoria_id | categorias.categoria_id | RESTRICT |
| productos.marca_id | marcas.marca_id | RESTRICT |
| producto_proveedor.producto_id | productos.producto_id | RESTRICT |
| producto_proveedor.proveedor_id | proveedores.proveedor_id | RESTRICT |
| ventas.cliente_id | clientes.cliente_id | RESTRICT |
| detalle_venta.venta_id | ventas.venta_id | RESTRICT |
| detalle_venta.producto_id | productos.producto_id | RESTRICT |

## Normalización

- **Primera forma normal:** cada celda contiene un dato escalar. No se guardan listas de proveedores ni de productos dentro de una columna. El JSON de entrada se convierte en filas de detalle.
- **Segunda forma normal:** las relaciones con PK compuesta tienen atributos que dependen de la clave completa. `costo_referencial` depende del par producto/proveedor; cantidad y precio histórico dependen del par venta/producto.
- **Tercera forma normal:** categoría, marca, proveedor y cliente se almacenan una sola vez y se referencian. Sus nombres no se duplican en la venta o en el catálogo como sustituto de una FK. Los campos de especificaciones describen la configuración identificada por el SKU.

`subtotal` es una **desnormalización controlada**: columna generada que depende de cantidad y precio. No puede modificarse manualmente. El total de cabecera no se almacena y se calcula en `v_ventas_resumen`. El precio histórico del detalle es un hecho de la venta y puede diferir del precio actual del producto. El stock es un saldo operativo actualizado por las funciones; no se modela un kardex de compras.

## Decisiones físicas

- PostgreSQL 16+, esquema `tienda`, base UTF8.
- Identificadores enteros `GENERATED ALWAYS AS IDENTITY` y PK compuestas donde no se necesita otra identidad.
- `numeric(12,2)` para precios; no se usa punto flotante para dinero. Subtotal `numeric(16,2)` y total de vista `numeric(18,2)`.
- `timestamptz` para conservar instantes; los reportes mensuales usan `America/Lima`.
- Claves `UNIQUE` para SKU, nombres de catálogos, RUC y documento del cliente.
- Índices adicionales para FK y consultas por cliente/fecha, fecha y producto; PK y UNIQUE ya crean sus propios índices.
- No hay borrado en cascada sobre información comercial. Los clientes, productos y proveedores se desactivan lógicamente.

## Vistas

| Vista | Finalidad |
| --- | --- |
| `tienda.v_ventas_resumen` | Cabecera y suma de subtotales, incluidas ventas anuladas |
| `tienda.v_stock_bajo` | Computadoras activas con stock menor o igual al mínimo |
