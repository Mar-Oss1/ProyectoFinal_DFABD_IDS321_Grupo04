/* 70 · FactVuelos (equivale a la vista vw_FactVuelosSource + DF_FactVuelos de SSIS).
   Grano: 1 vuelo real ADS-B. Solo entran vuelos con origen y destino
   (en SSIS lo hacía el Conditional Split CS_Validacion: EsVueloValido == 1).

   Cambios necesarios frente a SQL Server (documentar en la matriz):
   - TRY_CONVERT no existe: se valida el formato con una expresión regular antes de convertir.
   - geography::STDistance (elipsoide WGS84) no existe sin PostGIS: se usa la fórmula
     de Haversine (esfera de radio medio 6371.0088 km). Diferencia típica < 0.5 %.
   - CHECKSUM no existe: la variación aleatoria pero repetible de la simulación usa
     md5. Mismo rango de valores, pero NO los mismos valores por vuelo, por eso los
     totales de pasajeros/ingresos/retraso estimados difieren levemente de SQL Server.
   - DATEDIFF(MINUTE) cuenta cambios de minuto, se replica truncando a minuto
     antes de restar, para obtener exactamente la misma duración. */
INSERT INTO factvuelos (fechakey, horasalida, aerolineakey, avionkey,
                        aeropuertoorigenkey, aeropuertodestinokey, callsign, aircraftuid,
                        primeravista, ultimavista, duracionminutos, distanciakm,
                        esinternacional, esrutaofertada, asientosdisponibles,
                        pasajerosestimados, factorocupacionestimado,
                        ingresoestimadousd, retrasoestimadomin)
WITH p AS (            -- parámetros de simulación en una sola fila
    SELECT MAX(CASE WHEN parametro = 'AsientosPromedio'     THEN valor END) AS asientos,
           MAX(CASE WHEN parametro = 'FactorOcupacionBase'  THEN valor END) AS fbase,
           MAX(CASE WHEN parametro = 'FactorEstacionalAlta' THEN valor END) AS falta,
           MAX(CASE WHEN parametro = 'JitterRango'          THEN valor END) AS jitter,
           MAX(CASE WHEN parametro = 'TarifaUSDPorKm'       THEN valor END) AS tarifa,
           MAX(CASE WHEN parametro = 'RetrasoBaseMax'       THEN valor END) AS retmax,
           MAX(CASE WHEN parametro = 'RetrasoExtraPeak'     THEN valor END) AS retpeak
    FROM parametrossimulacion
),
v AS (                 -- vuelos con fechas válidas, ya convertidas
    SELECT s.callsign, s.aircraft_uid, s.typecode,
           NULLIF(s.origin, '')      AS origin,
           NULLIF(s.destination, '') AS destination,
           LEFT(s.firstseen, 19)::TIMESTAMP(0) AS primeravista,
           LEFT(s.lastseen, 19)::TIMESTAMP(0)  AS ultimavista,
           LEFT(s.day, 10)::DATE               AS fechavuelo,
           -- hash determinista 0..4294967295 (reemplaza a ABS(CHECKSUM(...)))
           ('x' || SUBSTR(MD5(COALESCE(s.aircraft_uid, '') || '|' || COALESCE(s.firstseen, '')), 1, 8))::BIT(32)::BIGINT AS h_ocup,
           ('x' || SUBSTR(MD5(COALESCE(s.callsign, '')     || '|' || COALESCE(s.aircraft_uid, '')), 1, 8))::BIT(32)::BIGINT AS h_ret
    FROM stg.os_flights s
    WHERE s.firstseen ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
      AND s.lastseen  ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
      AND s.day       ~ '^\d{4}-\d{2}-\d{2}'
),
w AS (                 -- lookups de dimensiones y medidas reales
    SELECT v.*,
           TO_CHAR(v.fechavuelo, 'YYYYMMDD')::INT        AS fechakey,
           EXTRACT(HOUR FROM v.primeravista)::SMALLINT   AS horasalida,
           (EXTRACT(EPOCH FROM DATE_TRUNC('minute', v.ultimavista)
                             - DATE_TRUNC('minute', v.primeravista)) / 60)::INT AS duracionminutos,
           COALESCE(al.aerolineakey, -1)   AS aerolineakey,
           COALESCE(av.avionkey, -1)       AS avionkey,
           COALESCE(o.aeropuertokey, -1)   AS aeropuertoorigenkey,
           COALESCE(d.aeropuertokey, -1)   AS aeropuertodestinokey,
           CASE WHEN o.latitud IS NULL OR d.latitud IS NULL THEN NULL
                ELSE 2 * 6371.0088 * ASIN(SQRT(LEAST(1,
                       SIN(RADIANS((d.latitud - o.latitud)::FLOAT) / 2) ^ 2
                     + COS(RADIANS(o.latitud::FLOAT)) * COS(RADIANS(d.latitud::FLOAT))
                     * SIN(RADIANS((d.longitud - o.longitud)::FLOAT) / 2) ^ 2)))
           END                             AS distancia,
           CASE WHEN o.codigopais IS NULL OR d.codigopais IS NULL THEN NULL
                ELSE o.codigopais <> d.codigopais END     AS esinternacional,
           (x.origen IS NOT NULL)          AS esrutaofertada
    FROM v
    LEFT JOIN dimaeropuerto o  ON o.icao  = v.origin
    LEFT JOIN dimaeropuerto d  ON d.icao  = v.destination
    LEFT JOIN dimaerolinea  al ON al.icao = LEFT(TRIM(v.callsign), 3)
    LEFT JOIN dimavion      av ON av.bk_codigotipo = RTRIM(v.typecode)
    LEFT JOIN xw_rutas_icao x  ON x.origen = v.origin AND x.destino = v.destination
    WHERE v.ultimavista > v.primeravista
      AND v.origin IS NOT NULL AND v.destination IS NOT NULL      -- EsVueloValido = 1
),
z AS (                 -- simulación (mismas reglas que SQL Server)
    SELECT w.*, p.asientos, p.tarifa,
           CASE WHEN (p.fbase
                      + CASE WHEN EXTRACT(MONTH FROM w.fechavuelo) IN (1, 7, 12) THEN p.falta ELSE 0 END
                      + (w.h_ocup % 100) / 1000.0
                      - p.jitter / 2)::NUMERIC(5,4) BETWEEN 0.55 AND 0.98
                THEN (p.fbase
                      + CASE WHEN EXTRACT(MONTH FROM w.fechavuelo) IN (1, 7, 12) THEN p.falta ELSE 0 END
                      + (w.h_ocup % 100) / 1000.0
                      - p.jitter / 2)::NUMERIC(5,4)
                ELSE 0.80 END                                            AS factoroc,
           (w.h_ret % p.retmax
            + CASE WHEN w.horasalida IN (7, 8, 9, 17, 18, 19) THEN p.retpeak ELSE 0 END)::INT AS retraso
    FROM w CROSS JOIN p
)
SELECT fechakey, horasalida, aerolineakey, avionkey,
       aeropuertoorigenkey, aeropuertodestinokey,
       LEFT(callsign, 20), LEFT(aircraft_uid, 40),
       primeravista, ultimavista, duracionminutos,
       ROUND(distancia::NUMERIC, 2),
       esinternacional, esrutaofertada,
       asientos::INT,
       ROUND(asientos * factoroc, 0)::INT,
       factoroc,
       CASE WHEN distancia IS NULL THEN NULL
            ELSE ROUND(ROUND(asientos * factoroc, 0) * tarifa * distancia::NUMERIC, 2) END,
       retraso
FROM z;
