-- Ejecutar con psql, no pegar este archivo en el editor de pgAdmin.
-- Las rutas \ir se resuelven respecto a este archivo.
\set ON_ERROR_STOP on
\ir 01_ddl.sql
\ir 02_funciones.sql
\ir 03_dml.sql
