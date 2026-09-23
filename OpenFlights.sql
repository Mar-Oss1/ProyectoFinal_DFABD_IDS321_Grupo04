USE OpenFlights;
GO

--PARA VER TODOS LOS ESQUEMAS
SELECT schema_name
FROM information_schema.schemata;
GO
--PARA VER TODAS LAS TABLAS DE UN ESQUEMA
SELECT table_name FROM information_schema.tables WHERE table_schema = '';
GO
--VER LAS COLUMNAS DE UNA TABLA CON SUS TIPOS DE DATOS
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'routes'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'airlines'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'airports'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'planes'
--   AND table_schema = '';

--VER LAS RELACIONES CON LAS TABLAS
SELECT
    fk.name AS FK_Name,
    tp.name AS Parent_Table,
    cp.name AS Parent_Column,
    tr.name AS Referenced_Table,
    cr.name AS Referenced_Column
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS tp ON fk.parent_object_id = tp.object_id
INNER JOIN sys.tables AS tr ON fk.referenced_object_id = tr.object_id
INNER JOIN sys.columns AS cp ON fk.parent_object_id = cp.object_id
INNER JOIN sys.columns AS cr ON fk.referenced_object_id = cr.object_id;


-- Conocer el esquema
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM OpenFlights.INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_NAME, ORDINAL_POSITION;


