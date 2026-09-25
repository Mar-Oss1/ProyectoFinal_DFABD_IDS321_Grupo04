/* ============================================================
   00 · STAGING + PARÁMETROS DE SIMULACIÓN
   RUNBOOK: paso 2 de 5 (tras restaurar OpenFlights.bak)
   RE-EJECUTABLE: SÍ (DROPpea y recarga; dedup post-carga)
   DECISIONES: B-06 aterrizaje crudo · B-14 icao+gps · B-24 dedup
   ============================================================ */
IF DB_ID('OpenFlightsDW') IS NULL CREATE DATABASE OpenFlightsDW;
GO
USE OpenFlightsDW;
GO

/* ---------- Staging OurAirports (maestro de aeropuertos) ----------
   DECISIÓN: incluimos icao_code + gps_code + iata_code porque OpenSky
   da ICAO en origin/destination y hay que emparejar con cualquiera. */
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
    id             INT,
    code           VARCHAR(16),
    local_code     VARCHAR(16),
    name           NVARCHAR(200),
    continent      CHAR(2),
    iso_country    CHAR(2),
    wikipedia_link VARCHAR(300),
    keywords       NVARCHAR(500)
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
   REGLA B-24: el BULK AGREGA filas. Re-ejecutar este archivo completo es
   seguro (DROP al inicio + dedup post-carga); re-ejecutar SOLO este bloque
   exige reset previo de las tablas. */
BULK INSERT dbo.oa_stg_airports
FROM 'C:\datos_dw\airports.csv'
WITH (FORMAT='CSV', FIRSTROW=2, CODEPAGE='65001', FIELDQUOTE='"',
      ROWTERMINATOR='0x0a', DATAFILETYPE='char', MAXERRORS=10000, TABLOCK);

BULK INSERT dbo.oa_stg_regions
FROM 'C:\datos_dw\regions.csv'
WITH (FORMAT='CSV', FIRSTROW=2, CODEPAGE='65001', FIELDQUOTE='"',
      ROWTERMINATOR='0x0a', DATAFILETYPE='char', MAXERRORS=10000, TABLOCK);

BULK INSERT dbo.oa_stg_countries
FROM 'C:\datos_dw\countries.csv'
WITH (FORMAT='CSV', FIRSTROW=2, CODEPAGE='65001', FIELDQUOTE='"',
      ROWTERMINATOR='0x0a', DATAFILETYPE='char', MAXERRORS=10000, TABLOCK);

BULK INSERT dbo.os_stg_flights
FROM 'C:\datos_dw\flightlist_20191201_20191231.csv'
WITH (FORMAT='CSV', FIRSTROW=2, CODEPAGE='65001',
      ROWTERMINATOR='0x0a', DATAFILETYPE='char', MAXERRORS=0, TABLOCK);
GO

/* ---------- DEDUP POST-CARGA (B-24): una copia por llave natural ---------- */
;WITH d AS (SELECT id, ROW_NUMBER() OVER (PARTITION BY ident ORDER BY id) rn
            FROM dbo.oa_stg_airports)
DELETE d WHERE rn > 1;

;WITH d AS (SELECT id, ROW_NUMBER() OVER (PARTITION BY id ORDER BY (SELECT NULL)) rn
            FROM dbo.oa_stg_regions)
DELETE d WHERE rn > 1;

;WITH d AS (SELECT id, ROW_NUMBER() OVER (PARTITION BY id ORDER BY (SELECT NULL)) rn
            FROM dbo.oa_stg_countries)
DELETE d WHERE rn > 1;

;WITH d AS (SELECT ROW_NUMBER() OVER (PARTITION BY aircraft_uid, firstseen
                                      ORDER BY (SELECT NULL)) rn
            FROM dbo.os_stg_flights)
DELETE d WHERE rn > 1;
GO

/* ---------- Perfil mínimo (esperado post-dedup) ----------
   airports 86,116 · regions 3,987 · countries 249 · flights 2,700,968 */
SELECT 'oa_stg_airports' AS tabla, COUNT(*) AS filas,
       SUM(CASE WHEN icao_code IS NULL OR icao_code='' THEN 1 ELSE 0 END) AS sin_icao,
       SUM(CASE WHEN iata_code IS NULL OR iata_code='' THEN 1 ELSE 0 END) AS sin_iata,
       SUM(CASE WHEN gps_code  IS NULL OR gps_code=''  THEN 1 ELSE 0 END) AS sin_gps
FROM dbo.oa_stg_airports
UNION ALL SELECT 'oa_stg_regions',  COUNT(*), NULL, NULL, NULL FROM dbo.oa_stg_regions
UNION ALL SELECT 'oa_stg_countries',COUNT(*), NULL, NULL, NULL FROM dbo.oa_stg_countries
UNION ALL SELECT 'os_stg_flights',  COUNT(*),
       SUM(CASE WHEN aircraft_uid IS NULL OR aircraft_uid='' THEN 1 ELSE 0 END),
       SUM(CASE WHEN origin IS NULL OR origin='' THEN 1 ELSE 0 END),
       SUM(CASE WHEN typecode IS NULL OR typecode='' THEN 1 ELSE 0 END)
FROM dbo.os_stg_flights;
GO

/* ---------- Parámetros de simulación (gobernanza de medidas estimadas) ---------- */
IF OBJECT_ID('dbo.ParametrosSimulacion') IS NULL
CREATE TABLE dbo.ParametrosSimulacion (
    Parametro   VARCHAR(50) PRIMARY KEY,
    Valor       DECIMAL(12,4) NOT NULL,
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

/* ---------- Índices para el ETL ---------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='ix_oa_stg_icao')
    CREATE INDEX ix_oa_stg_icao ON dbo.oa_stg_airports(icao_code);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='ix_os_stg_origen')
    CREATE INDEX ix_os_stg_origen ON dbo.os_stg_flights(origin);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='ix_os_stg_dest')
    CREATE INDEX ix_os_stg_dest ON dbo.os_stg_flights(destination);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='ix_oa_stg_regions_code')
    CREATE INDEX ix_oa_stg_regions_code ON dbo.oa_stg_regions(code);
GO

/* ---------- Cobertura entre fuentes (justifica las 3 fuentes; va en diapo) ---------- */
/* a nivel de aeropuertos (versión coalesce, B-14) */
WITH extremos AS (
    SELECT origin AS icao FROM dbo.os_stg_flights WHERE origin IS NOT NULL AND origin <> ''
    UNION
    SELECT destination FROM dbo.os_stg_flights WHERE destination IS NOT NULL AND destination <> ''
)
SELECT COUNT(*) AS aeropuertos_opensky,
       SUM(CASE WHEN ofa.airport_id IS NOT NULL THEN 1 ELSE 0 END) AS en_OpenFlights,
       SUM(CASE WHEN oa.id IS NOT NULL THEN 1 ELSE 0 END)          AS en_OurAirports_coalesce,
       SUM(CASE WHEN ofa.airport_id IS NOT NULL OR oa.id IS NOT NULL THEN 1 ELSE 0 END) AS en_alguna
FROM extremos e
OUTER APPLY (SELECT TOP 1 airport_id FROM OpenFlights.dbo.airports a WHERE a.icao = e.icao) ofa
OUTER APPLY (SELECT TOP 1 id FROM dbo.oa_stg_airports a
             WHERE a.icao_code = e.icao OR a.gps_code = e.icao) oa;

/* a nivel de vuelo (la cifra de la diapo) */
SELECT COUNT(*) AS vuelos_con_origen,
       SUM(CASE WHEN ofa.airport_id IS NULL THEN 1 ELSE 0 END) AS caerian_a_menos1_sin_OurAirports,
       SUM(CASE WHEN oa.id IS NULL THEN 1 ELSE 0 END)          AS caerian_a_menos1_sin_coalesce
FROM dbo.os_stg_flights s
OUTER APPLY (SELECT TOP 1 airport_id FROM OpenFlights.dbo.airports a WHERE a.icao = s.origin) ofa
OUTER APPLY (SELECT TOP 1 id FROM dbo.oa_stg_airports a
             WHERE a.icao_code = s.origin OR a.gps_code = s.origin) oa
WHERE s.origin IS NOT NULL AND s.origin <> '';
GO