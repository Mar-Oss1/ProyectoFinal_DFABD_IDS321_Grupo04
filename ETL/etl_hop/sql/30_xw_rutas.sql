/* 30 · Crosswalk de rutas ofertadas (equivale a SQL_Reconstruir_xw_rutas).
   Pares ICAO origen-destino que existen en el catálogo de rutas de OpenFlights. */
TRUNCATE TABLE xw_rutas_icao;
INSERT INTO xw_rutas_icao (origen, destino)
SELECT DISTINCT so.icao, sd.icao
FROM stg.of_routes r
JOIN stg.of_airports so ON so.airport_id = NULLIF(r.source_airport_id, '')
JOIN stg.of_airports sd ON sd.airport_id = NULLIF(r.dest_airport_id, '')
WHERE NULLIF(so.icao, '') IS NOT NULL
  AND NULLIF(sd.icao, '') IS NOT NULL;
