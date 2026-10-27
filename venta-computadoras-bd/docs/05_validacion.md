# Validación del entregable

## Ejecución realizada

Fecha: **27/10/2026**. Los scripts se ejecutaron en una base vacía usando **PostgreSQL 18.6 en WebAssembly, mediante PGlite 0.5.12**. No se usó un simulador de sintaxis SQL: se ejecutaron las tablas, restricciones, vistas y funciones PL/pgSQL. El proyecto usa funcionalidades disponibles desde PostgreSQL 16; no se ejecutó una instalación nativa de la versión 16 durante esta preparación.

| Componente | Resultado observado |
| --- | --- |
| 01_ddl.sql | Creación exitosa de 8 tablas, 50 columnas, índices y 2 vistas |
| 02_funciones.sql | Creación exitosa de registrar_venta y anular_venta |
| 03_dml.sql | Inserciones, 3 ventas y 1 anulación completadas |
| 04_consultas.sql | Las 8 consultas se ejecutaron sin error |
| 05_pruebas.sql | **46 comprobaciones correctas**; se revirtieron sus cambios |
| 06_permisos_opcionales.sql | Rol y concesiones creados sin error |
| 07_pruebas_permisos_opcionales.sql | **4 comprobaciones correctas** de escritura bloqueada/función permitida |
| OpenAPI | Documento validado con openapi-spec-validator: 12 rutas, 20 operaciones |
| Diagramas | PNG y SVG revisados visualmente; Mermaid editable incluido |
| Enlaces relativos | Archivos referenciados desde la documentación comprobados |

Resumen de ejecución de los scripts:

```text
01_ddl.sql: OK
02_funciones.sql: OK
03_dml.sql: OK
04_consultas.sql: OK
05_pruebas.sql: pruebas_correctas = 46
06_permisos_opcionales.sql: OK
07_pruebas_permisos_opcionales.sql: permisos_correctos = 4
```

Las pruebas abarcan totales, stock esperado, alertas, venta exitosa, preservación del precio histórico, anulación, doble anulación, rollback de cabecera/detalles/stock ante fallo de una línea, entradas inválidas, documentos, unicidad, integridad referencial y restricciones de borrado. Las pruebas de permisos rechazan modificar stock, insertar cabeceras y alterar detalles directamente, y permiten registrar una venta a través de la función.

## Resultados del DML

| Dato | Esperado y observado |
| --- | --- |
| Ventas 1 y 2 | CONFIRMADA, S/ 9 000.00 y S/ 4 600.00 |
| Venta 3 | ANULADA, importe histórico S/ 4 800.00 |
| Total de ventas confirmadas | S/ 13 600.00 |
| Stock de productos 1 a 6 | 9, 8, 10, 5, 5, 2 |
| Producto en alerta | 6, stock 2 / mínimo 2 |

## Reproducir en PostgreSQL nativo

Después de instalar los datos de demostración sin modificarlos:

```bash
psql -U postgres -d venta_computadoras -v ON_ERROR_STOP=1 -f database/05_pruebas.sql
```

Para validar los permisos, como administrador y una sola vez para crear el rol:

```bash
psql -U postgres -d venta_computadoras -v ON_ERROR_STOP=1 -f database/06_permisos_opcionales.sql
psql -U postgres -d venta_computadoras -v ON_ERROR_STOP=1 -f database/07_pruebas_permisos_opcionales.sql
```

Las pruebas dejan los datos como estaban, pero las secuencias pueden avanzar. `ON_ERROR_STOP` hace que `psql` se detenga si falla un archivo.

## Prueba manual de concurrencia pendiente en servidor

El motor embebido usado para validar no ofrece dos sesiones independientes como un servidor PostgreSQL. Por eso **no se afirma haber probado concurrencia real**. La implementación usa bloqueos de filas y se propone la siguiente prueba reproducible con dos conexiones en una base de demostración:

1. Confirmar que el producto 6 tiene stock 2 y está activo.
2. En la **sesión A**, ejecutar y dejar la transacción abierta:

   ```sql
   BEGIN;
   SELECT tienda.registrar_venta(1,'EFECTIVO','[{"producto_id":6,"cantidad":2}]');
   ```

3. En la **sesión B**, ejecutar:

   ```sql
   SELECT tienda.registrar_venta(2,'EFECTIVO','[{"producto_id":6,"cantidad":2}]');
   ```

4. B debe quedar esperando el bloqueo del producto. En A, ejecutar `COMMIT`.
5. B debe fallar por stock insuficiente. Consultar que el stock final sea 0 y que solo la venta de A se haya confirmado. Si B estaba en una transacción explícita, ejecutar `ROLLBACK`.
6. Para restaurar el saldo de demostración, anular la venta devuelta en A con un motivo de prueba. Esto conserva una venta adicional anulada; para repetir la suite de datos iniciales, usar otra base nueva.

## Límites de la comprobación

No se ejecutó una API HTTP porque no se exige su implementación ni se incluye servidor. El repositorio https://github.com/Huamani1569/venta-computadoras-bd fue creado y su página responde públicamente; al preparar esta actualización todavía estaba vacío. Falta subir estos archivos y verificar después su contenido en incógnito. El README ya incluye carrera y asignatura; el TXT incluye la URL real y fecha 27/10/2026.
