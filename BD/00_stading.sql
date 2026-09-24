--Comienzo de la creacion del DW

/* ============================================================
   00 · STAGING + PARÁMETROS DE SIMULACIÓN
   ============================================================ */
IF DB_ID('OpenFlightsDW') IS NULL CREATE DATABASE OpenFlightsDW;
GO
USE OpenFlightsDW;
GO

/* ---------- Staging OurAirports (maestro de aeropuertos) ----------
   ENCABEZADO REAL (19 columnas, con comillas):
   "id","ident","type","name","latitude_deg","longitude_deg",
   "elevation_ft","continent","iso_country","iso_region",
   "municipality","scheduled_service","icao_code","iata_code",
   "gps_code","local_code","home_link","wikipedia_link","keywords"
   DECISIÓN: incluimos icao_code + gps_code + iata_code porque
   OpenSky nos dará ICAO en origin/destination y hay que emparejar
   con cualquiera de los tres códigos que coincida. */
IF OBJECT_ID('dbo.oa_stg_airports') IS NOT NULL DROP TABLE dbo.oa_stg_airports;
CREATE TABLE dbo.oa_stg_airports (
    id                 INT,
    ident              VARCHAR(16),
    type               VARCHAR(30),
    name               NVARCHAR(200),
    latitude_deg       DECIMAL(18,10),
    longitude_deg      DECIMAL(18,10),
    elevation_ft       INT,
    continent          CHAR(2),
    iso_country        CHAR(2),
    iso_region         VARCHAR(16),
    municipality       NVARCHAR(100),
    scheduled_service  VARCHAR(3),
    icao_code          VARCHAR(4),
    iata_code          VARCHAR(5),
    gps_code           VARCHAR(4),
    local_code         VARCHAR(10),
    home_link          VARCHAR(300),
    wikipedia_link     VARCHAR(300),
    keywords           NVARCHAR(500)
);
GO

IF OBJECT_ID('dbo.oa_stg_regions') IS NOT NULL DROP TABLE dbo.oa_stg_regions;
CREATE TABLE dbo.oa_stg_regions (
    id           INT,
    code         VARCHAR(16),
    local_code   VARCHAR(16),
    name         NVARCHAR(200),
    continent    CHAR(2),
    iso_country  CHAR(2),
    wikipedia_link VARCHAR(300),
    keywords     NVARCHAR(500)
);
GO

IF OBJECT_ID('dbo.oa_stg_countries') IS NOT NULL DROP TABLE dbo.oa_stg_countries;
CREATE TABLE dbo.oa_stg_countries (
    id             INT,
    code           CHAR(2),
    name           NVARCHAR(200),
    continent      CHAR(2),
    wikipedia_link VARCHAR(300),
    keywords       NVARCHAR(500)
);
GO

/* ---------- Staging OpenSky (vuelos reales dic-2019) ----------
   ENCABEZADO REAL (15 columnas, SIN comillas):
   callsign, number, aircraft_uid, typecode, origin, destination,
   firstseen, lastseen, day,
   latitude_1, longitude_1, altitude_1,
   latitude_2, longitude_2, altitude_2
*/
IF OBJECT_ID('dbo.os_stg_flights') IS NOT NULL DROP TABLE dbo.os_stg_flights;
CREATE TABLE dbo.os_stg_flights (
    callsign      VARCHAR(20),
    number        VARCHAR(20),
    aircraft_uid  VARCHAR(40),
    typecode      VARCHAR(30),
    origin        VARCHAR(10),
    destination   VARCHAR(10),
    firstseen     VARCHAR(40),
    lastseen      VARCHAR(40),
    day           VARCHAR(30),
    latitude_1    VARCHAR(30),
    longitude_1   VARCHAR(30),
    altitude_1    VARCHAR(30),
    latitude_2    VARCHAR(30),
    longitude_2   VARCHAR(30),
    altitude_2    VARCHAR(30)
);
GO

/* ---------- Carga BULK INSERT ----------
   OurAirports: CSV con comillas, encabezado en fila 1 → FIRSTROW=2
   OpenSky:    CSV sin comillas, encabezado en fila 1 → FIRSTROW=2
   Ambos: UTF-8 (CODEPAGE 65001). Ajusta la ruta a tu carpeta real. */
/* OurAirports */
BULK INSERT dbo.oa_stg_airports
FROM 'C:\datos_dw\airports.csv'
WITH (FORMAT='CSV', FIRSTROW=2, CODEPAGE='65001', FIELDQUOTE='"',
      ROWTERMINATOR = '0x0a',       -- NUEVO: fuerza salto Unix
      DATAFILETYPE='char',          -- NUEVO: trata como texto plano
      MAXERRORS=10000, TABLOCK);

BULK INSERT dbo.oa_stg_regions
FROM 'C:\datos_dw\regions.csv'
WITH (FORMAT='CSV', FIRSTROW=2, CODEPAGE='65001', FIELDQUOTE='"',
      ROWTERMINATOR = '0x0a', DATAFILETYPE='char',
      MAXERRORS=10000, TABLOCK);

BULK INSERT dbo.oa_stg_countries
FROM 'C:\datos_dw\countries.csv'
WITH (FORMAT='CSV', FIRSTROW=2, CODEPAGE='65001', FIELDQUOTE='"',
      ROWTERMINATOR = '0x0a', DATAFILETYPE='char',
      MAXERRORS=10000, TABLOCK);

/* OpenSky */
BULK INSERT dbo.os_stg_flights
FROM 'C:\datos_dw\flightlist_20191201_20191231.csv'
WITH (FORMAT='CSV', FIRSTROW=2, CODEPAGE='65001',
      ROWTERMINATOR = '0x0a', DATAFILETYPE='char',
      MAXERRORS=0, TABLOCK);

/* ---------- Perfil mínimo del dataset */
SELECT 'oa_stg_airports'  AS tabla, COUNT(*) AS filas,
       SUM(CASE WHEN icao_code IS NULL OR icao_code='' THEN 1 ELSE 0 END) AS sin_icao,
       SUM(CASE WHEN iata_code IS NULL OR iata_code='' THEN 1 ELSE 0 END) AS sin_iata,
       SUM(CASE WHEN gps_code  IS NULL OR gps_code=''  THEN 1 ELSE 0 END) AS sin_gps
FROM dbo.oa_stg_airports
UNION ALL
SELECT 'oa_stg_regions', COUNT(*), NULL, NULL, NULL FROM dbo.oa_stg_regions
UNION ALL
SELECT 'oa_stg_countries', COUNT(*), NULL, NULL, NULL FROM dbo.oa_stg_countries
UNION ALL
SELECT 'os_stg_flights', COUNT(*),
       SUM(CASE WHEN aircraft_uid IS NULL OR aircraft_uid='' THEN 1 ELSE 0 END),
       SUM(CASE WHEN origin IS NULL OR origin='' THEN 1 ELSE 0 END),
       SUM(CASE WHEN typecode IS NULL OR typecode='' THEN 1 ELSE 0 END)
FROM dbo.os_stg_flights;
GO

/* ---------- Parámetros de simulación  ---------- */
IF OBJECT_ID('dbo.ParametrosSimulacion') IS NULL
CREATE TABLE dbo.ParametrosSimulacion (
    Parametro VARCHAR(50) PRIMARY KEY,
    Valor DECIMAL(12,4) NOT NULL,
    Descripcion VARCHAR(200)
);
MERGE dbo.ParametrosSimulacion AS t
USING (VALUES
 ('AsientosPromedio',        180.0, 'Asientos base por vuelo simulado'),
 ('FactorOcupacionBase',     0.800, 'Ocupación base'),
 ('FactorEstacionalAlta',    0.050, 'Bono de ocupación meses ene/jul/dic'),
 ('JitterRango',             0.100, 'Rango de variación determinista'),
 ('TarifaUSDPorKm',          0.090, 'Ingreso estimado por pasajero-km'),
 ('RetrasoBaseMax',          35.0,  'Minutos máximos de retraso base'),
 ('RetrasoExtraPeak',        10.0,  'Minutos extra en horas pico 7-9 y 17-19')
) AS s(Parametro, Valor, Descripcion)
ON t.Parametro = s.Parametro
WHEN MATCHED THEN UPDATE SET Valor = s.Valor, Descripcion = s.Descripcion
WHEN NOT MATCHED THEN INSERT VALUES (s.Parametro, s.Valor, s.Descripcion);
GO

--para documentar
SELECT COUNT(*) AS vuelos_cargados FROM dbo.os_stg_flights;

SELECT typecode, LEN(typecode) AS largo, COUNT(*) AS n
FROM dbo.os_stg_flights
WHERE LEN(typecode) > 4
GROUP BY typecode
ORDER BY n DESC;

--creacion de indices para agilizar el etl luego
CREATE INDEX ix_oa_stg_icao ON dbo.oa_stg_airports(icao_code);
CREATE INDEX ix_os_stg_origen ON dbo.os_stg_flights(origin);
CREATE INDEX ix_os_stg_dest ON dbo.os_stg_flights(destination);

--covertura a nivel de aeropuertos
WITH extremos AS (
    SELECT origin AS icao FROM dbo.os_stg_flights WHERE origin IS NOT NULL AND origin <> ''
    UNION
    SELECT destination FROM dbo.os_stg_flights WHERE destination IS NOT NULL AND destination <> ''
)
SELECT
    COUNT(*)                                                        AS aeropuertos_opensky,
    SUM(CASE WHEN ofa.airport_id IS NOT NULL THEN 1 ELSE 0 END)     AS existen_en_OpenFlights,
    SUM(CASE WHEN oa.icao_code  IS NOT NULL THEN 1 ELSE 0 END)      AS existen_en_OurAirports,
    SUM(CASE WHEN ofa.airport_id IS NOT NULL
           OR oa.icao_code  IS NOT NULL THEN 1 ELSE 0 END)          AS en_alguna_fuente
FROM extremos e
OUTER APPLY (SELECT TOP 1 airport_id FROM OpenFlights.dbo.airports a WHERE a.icao = e.icao) ofa
OUTER APPLY (SELECT TOP 1 icao_code FROM dbo.oa_stg_airports a WHERE a.icao_code = e.icao) oa;

--covertura a nivel de vuelo *(ira en la diapo)
SELECT
    COUNT(*) AS vuelos_con_origen,
    SUM(CASE WHEN ofa.airport_id IS NULL THEN 1 ELSE 0 END) AS caerian_a_menos1_sin_OurAirports,
    SUM(CASE WHEN oa.icao_code  IS NULL THEN 1 ELSE 0 END) AS caerian_a_menos1_sin_OpenFlights
FROM dbo.os_stg_flights s
OUTER APPLY (SELECT TOP 1 airport_id FROM OpenFlights.dbo.airports a WHERE a.icao = s.origin) ofa
OUTER APPLY (SELECT TOP 1 icao_code FROM dbo.oa_stg_airports a WHERE a.icao_code = s.origin) oa
WHERE s.origin IS NOT NULL AND s.origin <> '';


----
WITH extremos AS (
    SELECT origin AS icao FROM dbo.os_stg_flights WHERE origin IS NOT NULL AND origin <> ''
    UNION
    SELECT destination FROM dbo.os_stg_flights WHERE destination IS NOT NULL AND destination <> ''
)
SELECT COUNT(*) AS aeropuertos_opensky,
       SUM(CASE WHEN ofa.airport_id IS NOT NULL THEN 1 ELSE 0 END) AS en_OpenFlights,
       SUM(CASE WHEN oa.id IS NOT NULL THEN 1 ELSE 0 END) AS en_OurAirports_coalesce,
       SUM(CASE WHEN ofa.airport_id IS NOT NULL OR oa.id IS NOT NULL THEN 1 ELSE 0 END) AS en_alguna
FROM extremos e
OUTER APPLY (SELECT TOP 1 airport_id FROM OpenFlights.dbo.airports a WHERE a.icao = e.icao) ofa
OUTER APPLY (SELECT TOP 1 id FROM dbo.oa_stg_airports a
             WHERE a.icao_code = e.icao OR a.gps_code = e.icao) oa;
