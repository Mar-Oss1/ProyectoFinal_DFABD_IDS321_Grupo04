/* 40 · DimAerolinea (equivale a DF_DimAerolinea).
   Limpieza de caracteres de control: la aerolínea 3924 Peau Vavaʻu trae marcas
   de codificación ESC%G / ESC%@ que rompían la respuesta XML del cubo SSAS.
   En SQL Server hizo falta REPLACE con COLLATE binario, en PostgreSQL se usa
   regexp_replace, que compara por carácter sin reglas de intercalación. */
INSERT INTO dimaerolinea (bk_airlineid, nombre, alias, iata, icao, callsign, pais, activa)
SELECT airline_id, name,
       COALESCE(NULLIF(TRIM(alias), ''), 'Sin Alias'),
       COALESCE(NULLIF(TRIM(iata), ''), 'S/I'),
       icao,
       COALESCE(NULLIF(TRIM(callsign), ''), 'Sin Callsign'),
       COALESCE(NULLIF(TRIM(country), ''), 'Sin Pais'),
       activa
FROM (
    SELECT a.airline_id::INT                                         AS airline_id,
           regexp_replace(regexp_replace(a.name, E'\\x1B%[G@]', '', 'g'),
                          E'[\\x01-\\x1F]', '', 'g')                 AS name,
           NULLIF(a.alias, '\N')                                     AS alias,
           LEFT(a.iata, 5)                                           AS iata,
           CASE WHEN TRIM(a.icao) ~ '^[A-Z0-9]{3,4}$' THEN TRIM(a.icao) END AS icao,
           LEFT(a.callsign, 50)                                      AS callsign,
           a.country,
           CASE a.active WHEN '1' THEN 'Si' WHEN '0' THEN 'No' ELSE 'ND' END AS activa,
           ROW_NUMBER() OVER (
               PARTITION BY COALESCE(CASE WHEN TRIM(a.icao) ~ '^[A-Z0-9]{3,4}$'
                                          THEN TRIM(a.icao) END,
                                     'NK-' || a.airline_id)
               ORDER BY a.airline_id::INT)                           AS rn
    FROM stg.of_airlines a
) x
WHERE x.rn = 1
  AND NOT EXISTS (SELECT 1 FROM dimaerolinea d WHERE d.bk_airlineid = x.airline_id);
