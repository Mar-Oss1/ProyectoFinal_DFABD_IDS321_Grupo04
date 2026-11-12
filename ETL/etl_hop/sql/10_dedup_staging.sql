/* 10 · Dedup del staging (equivale al bloque DEDUP POST-CARGA de 00_stading.sql)
   Una copia por llave natural. En SQL Server se usó ROW_NUMBER + DELETE sobre CTE,
   PostgreSQL no permite DELETE sobre un CTE, así que se identifica cada fila
   física con ctid (su dirección interna en la tabla). */
DELETE FROM stg.oa_airports t USING (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY ident ORDER BY id::INT) AS rn
    FROM stg.oa_airports) d
WHERE t.ctid = d.ctid AND d.rn > 1;

DELETE FROM stg.oa_regions t USING (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY id) AS rn FROM stg.oa_regions) d
WHERE t.ctid = d.ctid AND d.rn > 1;

DELETE FROM stg.oa_countries t USING (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY id) AS rn FROM stg.oa_countries) d
WHERE t.ctid = d.ctid AND d.rn > 1;

DELETE FROM stg.os_flights t USING (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY aircraft_uid, firstseen) AS rn
    FROM stg.os_flights) d
WHERE t.ctid = d.ctid AND d.rn > 1;
