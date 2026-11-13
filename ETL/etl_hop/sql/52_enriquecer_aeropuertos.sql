/* 52 · Enriquecer aeropuertos (equivale a SQL_Enriquecer_Aeropuertos).
   1) Nombre del país desde OurAirports.  2) Zona horaria y país faltante desde OpenFlights.
   3) Continente faltante desde el país en OurAirports countries
      (los aeropuertos del complemento OpenFlights no traen continente). */
UPDATE dimaeropuerto d
SET paisnombre = c.name
FROM stg.oa_countries c
WHERE c.code = d.codigopais
  AND d.aeropuertokey <> -1
  AND d.paisnombre IS NULL;

UPDATE dimaeropuerto d
SET zonahoraria = (SELECT NULLIF(a.tz_olson, '') FROM stg.of_airports a
                   WHERE a.icao = d.icao ORDER BY a.airport_id::INT LIMIT 1),
    paisnombre  = COALESCE(d.paisnombre,
                           (SELECT c.name FROM stg.of_countries c
                            WHERE c.iso_code = d.codigopais LIMIT 1))
WHERE d.aeropuertokey <> -1
  AND (d.zonahoraria IS NULL OR d.paisnombre IS NULL);

UPDATE dimaeropuerto d
SET continente = c.continent
FROM stg.oa_countries c
WHERE c.code = d.codigopais
  AND d.aeropuertokey <> -1
  AND d.continente IS NULL;
