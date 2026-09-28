/* ============================================================
   01 · CREACIÓN DEL DATA WAREHOUSE (esquema estrella)
   RUNBOOK: paso 3 de 5
   RE-EJECUTABLE: SÍ (guardas IF NOT EXISTS + semillas con guarda por BK)
   DECISIONES: B-11 miembros -1 · B-20 guardas · B-26 semillas por BK
   ============================================================ */
USE OpenFlightsDW;
GO

/* DimFecha: calendario GENERADO (dimensión estructural, no dato simulado) */
IF OBJECT_ID('dbo.DimFecha') IS NULL
CREATE TABLE dbo.DimFecha (
    FechaKey      INT PRIMARY KEY,
    Fecha         DATE NOT NULL,
    Anio          INT  NOT NULL,
    Trimestre     INT  NOT NULL,
    Mes           INT  NOT NULL,
    NombreMes     VARCHAR(10),
    Dia           INT  NOT NULL,
    NombreDia     VARCHAR(10),
    EsFinDeSemana BIT  NOT NULL
);
IF NOT EXISTS (SELECT 1 FROM dbo.DimFecha)
BEGIN
    ;WITH n AS (SELECT TOP (731) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i
                FROM sys.columns a CROSS JOIN sys.columns b)
    INSERT INTO dbo.DimFecha
    SELECT CONVERT(INT, FORMAT(DATEADD(DAY,i,'2019-01-01'),'yyyyMMdd')),
           DATEADD(DAY,i,'2019-01-01'),
           YEAR(DATEADD(DAY,i,'2019-01-01')),
           DATEPART(QUARTER, DATEADD(DAY,i,'2019-01-01')),
           MONTH(DATEADD(DAY,i,'2019-01-01')),
           CHOOSE(MONTH(DATEADD(DAY,i,'2019-01-01')),
                  'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                  'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'),
           DAY(DATEADD(DAY,i,'2019-01-01')),
           CHOOSE(DATEPART(WEEKDAY, DATEADD(DAY,i,'2019-01-01')),
                  'Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'),
           CASE WHEN DATEPART(WEEKDAY, DATEADD(DAY,i,'2019-01-01')) IN (1,7) THEN 1 ELSE 0 END
    FROM n;
END
GO

/* DimAeropuerto: maestro OurAirports + complemento OpenFlights */
IF OBJECT_ID('dbo.DimAeropuerto') IS NULL
CREATE TABLE dbo.DimAeropuerto (
    AeropuertoKey      INT IDENTITY(-1,1) PRIMARY KEY,
    BK_Ident           VARCHAR(20) NOT NULL UNIQUE,
    ICAO               VARCHAR(4),
    IATA               VARCHAR(5),
    Nombre             NVARCHAR(200),
    Ciudad             NVARCHAR(100),
    CodigoPais         CHAR(2),
    PaisNombre         NVARCHAR(200),
    RegionCodigo       VARCHAR(16),
    RegionNombre       NVARCHAR(200),
    Continente         CHAR(2),
    Latitud            DECIMAL(11,7),
    Longitud           DECIMAL(11,7),
    ElevationFt        INT,
    TipoAeropuerto     VARCHAR(50),
    ServicioProgramado VARCHAR(30),
    ZonaHoraria        VARCHAR(50),
    OrigenFuente       VARCHAR(12) NOT NULL DEFAULT 'OurAirports'
);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_DimAeropuerto_ICAO')
    CREATE UNIQUE INDEX UX_DimAeropuerto_ICAO ON dbo.DimAeropuerto(ICAO) WHERE ICAO IS NOT NULL;
GO

/* DimAerolinea: maestro OpenFlights */
IF OBJECT_ID('dbo.DimAerolinea') IS NULL
CREATE TABLE dbo.DimAerolinea (
    AerolineaKey INT IDENTITY(-1,1) PRIMARY KEY,
    BK_AirlineID INT NOT NULL UNIQUE,
    Nombre       NVARCHAR(200),
    Alias        NVARCHAR(200),
    IATA         VARCHAR(5),
    ICAO         VARCHAR(4),
    Callsign     VARCHAR(50),
    Pais         NVARCHAR(100),
    Activa       VARCHAR(2)
);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_DimAerolinea_ICAO')
    CREATE UNIQUE INDEX UX_DimAerolinea_ICAO ON dbo.DimAerolinea(ICAO) WHERE ICAO IS NOT NULL;
GO

/* DimAvion: unión OpenSky (typecode) + rutas OpenFlights (equipment) */
IF OBJECT_ID('dbo.DimAvion') IS NULL
CREATE TABLE dbo.DimAvion (
    AvionKey       INT IDENTITY(-1,1) PRIMARY KEY,
    BK_CodigoTipo  VARCHAR(30) NOT NULL UNIQUE,
    OrigenRegistro VARCHAR(20)
);
GO

/* FactVuelos: grano = 1 vuelo real ADS-B */
IF OBJECT_ID('dbo.FactVuelos') IS NULL
CREATE TABLE dbo.FactVuelos (
    VueloKey                BIGINT IDENTITY(1,1) PRIMARY KEY,
    FechaKey                INT          NOT NULL REFERENCES dbo.DimFecha(FechaKey),
    HoraSalida              TINYINT      NOT NULL,
    AerolineaKey            INT          NOT NULL REFERENCES dbo.DimAerolinea(AerolineaKey),
    AvionKey                INT          NOT NULL REFERENCES dbo.DimAvion(AvionKey),
    AeropuertoOrigenKey     INT          NOT NULL REFERENCES dbo.DimAeropuerto(AeropuertoKey),
    AeropuertoDestinoKey    INT          NOT NULL REFERENCES dbo.DimAeropuerto(AeropuertoKey),
    Callsign                VARCHAR(20),
    AircraftUID             VARCHAR(40),
    PrimeraVista            DATETIME2(0) NOT NULL,
    UltimaVista             DATETIME2(0) NOT NULL,
    CantidadVuelos          INT          NOT NULL DEFAULT 1,
    DuracionMinutos         INT,
    DistanciaKm             DECIMAL(10,2),
    EsInternacional         BIT,
    EsRutaOfertada          BIT,
    AsientosDisponibles     INT,
    PasajerosEstimados      INT,
    FactorOcupacionEstimado DECIMAL(5,4),
    IngresoEstimadoUSD      DECIMAL(12,2),
    RetrasoEstimadoMin      INT,
    CONSTRAINT UQ_FactVuelos UNIQUE (AircraftUID, PrimeraVista)
);
GO

/* Crosswalk de rutas: pares ICAO ofertados (equi-join rápido para EsRutaOfertada) */
IF OBJECT_ID('dbo.xw_rutas_icao') IS NULL
CREATE TABLE dbo.xw_rutas_icao (
    origen  VARCHAR(4) NOT NULL,
    destino VARCHAR(4) NOT NULL,
    CONSTRAINT PK_xw_rutas PRIMARY KEY (origen, destino)
);
GO

/* Log de carga: evidencia ejecutable del ETL */
IF OBJECT_ID('dbo.LogCarga') IS NULL
CREATE TABLE dbo.LogCarga (
    LogId              INT IDENTITY PRIMARY KEY,
    Inicio             DATETIME2,
    Fin                DATETIME2,
    FilasDimAeropuerto INT,
    FilasDimAerolinea  INT,
    FilasDimAvion      INT,
    FilasFactVuelos    INT,
    Estado             VARCHAR(20),
    Error              NVARCHAR(500)
);
GO

/* ---------- MIEMBROS -1: datos de DISEÑO, no de carga (B-11, B-26) ----------
   Guarda por llave de negocio: sobreviven a toda re-ejecución. */
IF NOT EXISTS (SELECT 1 FROM dbo.DimAeropuerto WHERE BK_Ident = 'DESCONOCIDO')
BEGIN
    SET IDENTITY_INSERT dbo.DimAeropuerto ON;
    INSERT INTO dbo.DimAeropuerto (AeropuertoKey, BK_Ident, Nombre, OrigenFuente)
    VALUES (-1, 'DESCONOCIDO', N'Aeropuerto no catalogado', 'N/D');
    SET IDENTITY_INSERT dbo.DimAeropuerto OFF;
END
IF NOT EXISTS (SELECT 1 FROM dbo.DimAerolinea WHERE BK_AirlineID = -1)
BEGIN
    SET IDENTITY_INSERT dbo.DimAerolinea ON;
    INSERT INTO dbo.DimAerolinea (AerolineaKey, BK_AirlineID, Nombre, Activa)
    VALUES (-1, -1, N'Aerolínea no identificada', 'ND');
    SET IDENTITY_INSERT dbo.DimAerolinea OFF;
END
IF NOT EXISTS (SELECT 1 FROM dbo.DimAvion WHERE BK_CodigoTipo = 'DESC')
BEGIN
    SET IDENTITY_INSERT dbo.DimAvion ON;
    INSERT INTO dbo.DimAvion (AvionKey, BK_CodigoTipo, OrigenRegistro)
    VALUES (-1, 'DESC', 'N/D');
    SET IDENTITY_INSERT dbo.DimAvion OFF;
END
GO

/* ---------- Chequeos post-creación (esperado: 731/1/1/1/0/0/0) ---------- */
SELECT (SELECT COUNT(*) FROM dbo.DimFecha)      AS dim_fecha,
       (SELECT COUNT(*) FROM dbo.DimAeropuerto) AS dim_aeropuerto,
       (SELECT COUNT(*) FROM dbo.DimAerolinea)  AS dim_aerolinea,
       (SELECT COUNT(*) FROM dbo.DimAvion)      AS dim_avion,
       (SELECT COUNT(*) FROM dbo.FactVuelos)    AS hechos,
       (SELECT COUNT(*) FROM dbo.xw_rutas_icao) AS xw_rutas,
       (SELECT COUNT(*) FROM dbo.LogCarga)      AS logs;
GO

--creacion de vista
IF OBJECT_ID('dbo.vw_FactVuelosSource') IS NOT NULL
    DROP VIEW dbo.vw_FactVuelosSource;
GO
CREATE VIEW dbo.vw_FactVuelosSource AS
SELECT FechaKey, HoraSalida, AerolineaKey, AvionKey,
       AeropuertoOrigenKey, AeropuertoDestinoKey,
       Callsign, AircraftUID, PrimeraVista, UltimaVista,
       DuracionMinutos, DistanciaKm, EsInternacional, EsRutaOfertada,
       AsientosDisponibles, PasajerosEstimados, FactorOcupacionEstimado,
       IngresoEstimadoUSD, RetrasoEstimadoMin, EsVueloValido
FROM (
    SELECT w.*,
           CONVERT(INT, Asientos)                      AS AsientosDisponibles,
           CONVERT(INT, ROUND(Asientos * FactorOc, 0)) AS PasajerosEstimados,
           CONVERT(DECIMAL(5,4), FactorOc)             AS FactorOcupacionEstimado,
           CASE WHEN DistanciaKm IS NULL THEN NULL
                ELSE ROUND(CONVERT(INT, ROUND(Asientos * FactorOc, 0)) * Tarifa * DistanciaKm, 2)
           END                                         AS IngresoEstimadoUSD,
           Retraso                                     AS RetrasoEstimadoMin,
           CASE WHEN origin IS NULL OR origin = '' OR destination IS NULL OR destination = ''
                THEN 0 ELSE 1 END                      AS EsVueloValido
    FROM (
        SELECT v.Callsign, v.AircraftUID, v.typecode, v.PrimeraVista, v.UltimaVista,
               v.origin, v.destination, v.Asientos, v.Tarifa, v.FactorOc, v.Retraso,
               CONVERT(INT, FORMAT(v.FechaVuelo,'yyyyMMdd'))   AS FechaKey,
               DATEPART(HOUR, v.PrimeraVista)                  AS HoraSalida,
               DATEDIFF(MINUTE, v.PrimeraVista, v.UltimaVista) AS DuracionMinutos,
               ISNULL(al.AerolineaKey,-1)   AS AerolineaKey,
               ISNULL(av.AvionKey,-1)       AS AvionKey,
               ISNULL(do_.AeropuertoKey,-1) AS AeropuertoOrigenKey,
               ISNULL(dd.AeropuertoKey,-1)  AS AeropuertoDestinoKey,
               CASE WHEN do_.Latitud IS NULL OR dd.Latitud IS NULL THEN NULL ELSE
                    geography::Point(do_.Latitud, do_.Longitud, 4326)
                      .STDistance(geography::Point(dd.Latitud, dd.Longitud, 4326)) / 1000.0
               END AS DistanciaKm,
               CASE WHEN do_.CodigoPais IS NULL OR dd.CodigoPais IS NULL THEN NULL
                    WHEN do_.CodigoPais <> dd.CodigoPais THEN 1 ELSE 0 END AS EsInternacional,
               CASE WHEN x.origen IS NOT NULL THEN 1 ELSE 0 END AS EsRutaOfertada
        FROM (
            SELECT s.callsign AS Callsign, s.aircraft_uid AS AircraftUID, s.typecode,
                   s.origin, s.destination,
                   TRY_CONVERT(DATETIME2(0), LEFT(s.firstseen,19)) AS PrimeraVista,
                   TRY_CONVERT(DATETIME2(0), LEFT(s.lastseen,19))  AS UltimaVista,
                   TRY_CONVERT(DATE, LEFT(s.day,10))               AS FechaVuelo,
                   p.Asientos, p.Tarifa,
                   CASE WHEN CONVERT(DECIMAL(5,4),
                         p.FBase + CASE WHEN MONTH(TRY_CONVERT(DATE,LEFT(s.day,10))) IN (1,7,12)
                                        THEN p.FAlta ELSE 0 END
                         + (ABS(CHECKSUM(s.aircraft_uid, s.firstseen)) % 100) / 1000.0
                         - p.Jitter / 2) BETWEEN 0.55 AND 0.98
                        THEN CONVERT(DECIMAL(5,4),
                         p.FBase + CASE WHEN MONTH(TRY_CONVERT(DATE,LEFT(s.day,10))) IN (1,7,12)
                                        THEN p.FAlta ELSE 0 END
                         + (ABS(CHECKSUM(s.aircraft_uid, s.firstseen)) % 100) / 1000.0
                         - p.Jitter / 2)
                        ELSE 0.80 END AS FactorOc,
                   ABS(CHECKSUM(s.callsign, s.aircraft_uid)) % p.RetMax
                     + CASE WHEN DATEPART(HOUR, TRY_CONVERT(DATETIME2(0), LEFT(s.firstseen,19)))
                                 IN (7,8,9,17,18,19) THEN p.RetPeak ELSE 0 END AS Retraso
            FROM dbo.os_stg_flights s
            CROSS JOIN (SELECT
                  MAX(CASE WHEN Parametro='AsientosPromedio'     THEN Valor END) AS Asientos,
                  MAX(CASE WHEN Parametro='FactorOcupacionBase'  THEN Valor END) AS FBase,
                  MAX(CASE WHEN Parametro='FactorEstacionalAlta' THEN Valor END) AS FAlta,
                  MAX(CASE WHEN Parametro='JitterRango'          THEN Valor END) AS Jitter,
                  MAX(CASE WHEN Parametro='TarifaUSDPorKm'       THEN Valor END) AS Tarifa,
                  MAX(CASE WHEN Parametro='RetrasoBaseMax'       THEN Valor END) AS RetMax,
                  MAX(CASE WHEN Parametro='RetrasoExtraPeak'     THEN Valor END) AS RetPeak
                FROM dbo.ParametrosSimulacion) p
            WHERE TRY_CONVERT(DATETIME2(0), LEFT(s.firstseen,19)) IS NOT NULL
              AND TRY_CONVERT(DATETIME2(0), LEFT(s.lastseen,19))  IS NOT NULL
              AND TRY_CONVERT(DATE, LEFT(s.day,10))               IS NOT NULL
              AND TRY_CONVERT(DATETIME2(0), LEFT(s.lastseen,19))
                > TRY_CONVERT(DATETIME2(0), LEFT(s.firstseen,19))
        ) v
        LEFT JOIN dbo.DimAeropuerto do_ ON do_.ICAO = v.origin
        LEFT JOIN dbo.DimAeropuerto dd  ON dd.ICAO  = v.destination
        LEFT JOIN dbo.DimAerolinea al   ON al.ICAO  = LEFT(LTRIM(RTRIM(v.Callsign)),3)
        LEFT JOIN dbo.DimAvion     av   ON av.BK_CodigoTipo = v.typecode
        LEFT JOIN dbo.xw_rutas_icao x   ON x.origen = v.origin AND x.destino = v.destination
    ) w
) z;
GO