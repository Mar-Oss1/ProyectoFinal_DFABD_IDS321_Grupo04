/* 50 · DimAeropuerto desde OurAirports, el maestro (equivale a DF_DimAeropuerto_OA).
   ICAO = icao_code, o gps_code si no hay. Si dos aeropuertos comparten ICAO,
   gana el que tiene servicio programado y luego el de menor id. */
INSERT INTO dimaeropuerto (bk_ident, icao, iata, nombre, ciudad, codigopais,
                           regioncodigo, regionnombre, continente, latitud, longitud,
                           elevationft, tipoaeropuerto, servicioprogramado, origenfuente)
SELECT ident, icao, COALESCE(iata, 'S/I'), name, COALESCE(municipality, 'Sin Ciudad'),
       iso_country, iso_region, region_nombre, continent,
       latitude_deg, longitude_deg, elevation_ft, type, scheduled_service, 'OurAirports'
FROM (
    SELECT a.ident,
           COALESCE(NULLIF(a.icao_code, ''), NULLIF(a.gps_code, ''))  AS icao,
           NULLIF(a.iata_code, '')                                     AS iata,
           a.name,
           NULLIF(a.municipality, '')                                  AS municipality,
           a.iso_country, a.iso_region,
           r.name                                                      AS region_nombre,
           a.continent,
           a.latitude_deg::NUMERIC(11,7)                               AS latitude_deg,
           a.longitude_deg::NUMERIC(11,7)                              AS longitude_deg,
           NULLIF(a.elevation_ft, '')::INT                             AS elevation_ft,
           a.type, a.scheduled_service,
           ROW_NUMBER() OVER (
               PARTITION BY COALESCE(NULLIF(a.icao_code, ''), NULLIF(a.gps_code, ''), a.ident)
               ORDER BY CASE WHEN a.scheduled_service = 'yes' THEN 0 ELSE 1 END,
                        a.id::INT)                                     AS rn
    FROM stg.oa_airports a
    LEFT JOIN LATERAL (SELECT r.name FROM stg.oa_regions r
                       WHERE r.code = a.iso_region LIMIT 1) r ON TRUE
) x
WHERE x.rn = 1
  AND NOT EXISTS (SELECT 1 FROM dimaeropuerto d WHERE d.bk_ident = x.ident);
