/* 51 · Complemento OpenFlights (equivale a DF_DimAeropuerto_OF_complemento).
   Solo aeropuertos con ICAO válido de 4 caracteres que OurAirports NO tiene. */
INSERT INTO dimaeropuerto (bk_ident, icao, iata, nombre, ciudad, codigopais, paisnombre,
                           latitud, longitud, elevationft, zonahoraria, origenfuente)
SELECT 'OF-' || airport_id, icao,
       COALESCE(NULLIF(iata, ''), 'S/I'), name,
       COALESCE(NULLIF(city, ''), 'Sin Ciudad'),
       iso_code,
       COALESCE(NULLIF(country, ''), 'Sin Pais'),
       latitude, longitude, altitude_ft,
       COALESCE(NULLIF(tz_olson, ''), 'Sin Zona Horaria'),
       'OpenFlights'
FROM (
    SELECT a.airport_id::INT                 AS airport_id,
           a.icao, a.iata, a.name, a.city, a.country,
           a.latitude::NUMERIC(11,7)         AS latitude,
           a.longitude::NUMERIC(11,7)        AS longitude,
           NULLIF(a.altitude_ft, '')::INT    AS altitude_ft,
           a.tz_olson,
           c.iso_code,
           ROW_NUMBER() OVER (PARTITION BY a.icao ORDER BY a.airport_id::INT) AS rn
    FROM stg.of_airports a
    LEFT JOIN LATERAL (SELECT c.iso_code FROM stg.of_countries c
                       WHERE c.name = a.country LIMIT 1) c ON TRUE
    WHERE a.icao ~ '^[A-Z0-9]{4}$'
) x
WHERE x.rn = 1
  AND NOT EXISTS (SELECT 1 FROM dimaeropuerto d WHERE d.icao = x.icao);
