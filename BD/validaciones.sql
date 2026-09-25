/* ============================================================
   02 · VALIDACIONES (solo lectura:D
   RUNBOOK: paso 5 de 5 (después de ejecutar el paquete SSIS)
   Cada bloque dice su resultado ESPERADO para auditoría rápida.
   ============================================================ */
USE OpenFlightsDW;
GO

/* --- A. Staging post-00 (esperado: 86,116 / 3,987 / 249 / 2,700,968
       y filas == unicos, prueba de que el dedup corrió) --- */
SELECT 'airports' t, COUNT(*) filas, COUNT(DISTINCT ident) unicos FROM dbo.oa_stg_airports
UNION ALL SELECT 'regions',  COUNT(*), COUNT(DISTINCT id) FROM dbo.oa_stg_regions
UNION ALL SELECT 'countries',COUNT(*), COUNT(DISTINCT id) FROM dbo.oa_stg_countries
UNION ALL SELECT 'flights',  COUNT(*), COUNT(DISTINCT CONCAT(aircraft_uid,'|',firstseen))
FROM dbo.os_stg_flights;

/* --- B. Dimensiones post-ETL --- */
SELECT COUNT(*) AS dim_avion      FROM dbo.DimAvion;       -- ~4,571 (4,570 + -1)
SELECT COUNT(*) AS dim_aerolinea  FROM dbo.DimAerolinea;   -- ~6,1xx + -1
SELECT COUNT(*) AS dim_aeropuerto FROM dbo.DimAeropuerto;  -- 85,656 + 392 + 1

SELECT OrigenFuente, COUNT(*) AS n FROM dbo.DimAeropuerto GROUP BY OrigenFuente;
-- OurAirports 85,656 · OpenFlights 392 · N/D 1

SELECT COUNT(*) AS complemento_OF FROM dbo.DimAeropuerto WHERE BK_Ident LIKE 'OF-%';  -- 392

SELECT COUNT(*) AS icao_duplicados   -- debe ser 0 (maestro y complemento no se pisan)
FROM (SELECT ICAO FROM dbo.DimAeropuerto WHERE ICAO IS NOT NULL
      GROUP BY ICAO HAVING COUNT(*) > 1) x;

SELECT COUNT(*) AS con_zona_horaria FROM dbo.DimAeropuerto WHERE ZonaHoraria IS NOT NULL;
SELECT COUNT(*) AS con_pais_nombre  FROM dbo.DimAeropuerto WHERE PaisNombre IS NOT NULL;

SELECT COUNT(*) AS con_icao  FROM dbo.DimAeropuerto WHERE ICAO IS NOT NULL;   -- ~31,5xx
SELECT COUNT(*) AS con_region FROM dbo.DimAeropuerto WHERE RegionNombre IS NOT NULL;

/* --- C. Miembros -1 vivos (esperado 1/1/1) --- */
SELECT 'DimAeropuerto' t, COUNT(*) n FROM dbo.DimAeropuerto WHERE AeropuertoKey = -1
UNION ALL SELECT 'DimAerolinea', COUNT(*) FROM dbo.DimAerolinea  WHERE AerolineaKey  = -1
UNION ALL SELECT 'DimAvion',     COUNT(*) FROM dbo.DimAvion      WHERE AvionKey      = -1;

/* --- D. Hecho post-ETL --- */
SELECT COUNT(*) AS vuelos FROM dbo.FactVuelos;                          -- ~1.94M
SELECT MIN(PrimeraVista) AS desde, MAX(PrimeraVista) AS hasta FROM dbo.FactVuelos;  -- dic-2019
SELECT SUM(CantidadVuelos) AS vuelos_sum, AVG(DuracionMinutos) AS dur_prom,
       AVG(DistanciaKm) AS km_prom FROM dbo.FactVuelos;
SELECT SUM(PasajerosEstimados) AS pax, SUM(IngresoEstimadoUSD) AS ingresos,
       AVG(FactorOcupacionEstimado) AS ocu_prom, AVG(RetrasoEstimadoMin) AS retraso_prom
FROM dbo.FactVuelos;
SELECT EsInternacional, COUNT(*) AS n FROM dbo.FactVuelos GROUP BY EsInternacional;
SELECT EsRutaOfertada,  COUNT(*) AS n FROM dbo.FactVuelos GROUP BY EsRutaOfertada;
SELECT COUNT(*) AS origen_menos1 FROM dbo.FactVuelos WHERE AeropuertoOrigenKey = -1;  -- cola larga medida

/* --- E. Log de carga (evidencia de corrida) --- */
SELECT * FROM dbo.LogCarga ORDER BY LogId DESC;
GO

SELECT COUNT(*) FROM dbo.os_stg_flights;