/*Creacion del DW - OpenflightsDW */

use OpenFlightsDW;
GO;

/* DimFecha */

IF OBJECT_ID('dbo.DimFecha') IS NULL
CREATE TABLE dbo.DimFecha
(
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
IF NOT EXISTS(SELECT 1
              FROM dbo.DimFecha)
    BEGIN
        ;
        WITH n AS (SELECT TOP (731) ROW_NUMBER() over (ORDER BY (SELECT NULL)) - 1 as i
                   FROM sys.columns a
                            CROSS JOIN sys.columns b)
        INSERT
        INTO dbo.DimFecha
        SELECT CONVERT(INT, FORMAT(DATEADD(DAY, i, '2019-01-01'), 'yyyyMMdd')),
               DATEADD(DAY, i, '2019-01-01'),
               YEAR(DATEADD(DAY, i, '2019-01-01')),
               DATEPART(QUARTER, DATEADD(DAY, i, '2019-01-01')),
               MONTH(DATEADD(DAY, i, '2019-01-01')),
               CHOOSE(MONTH(DATEADD(DAY, i, '2019-01-01')), 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'),
               DAY(DATEADD(DAY, i, '2019-01-01')),
               CHOOSE(DATEPART(WEEKDAY, DATEADD(DAY, i, '2019-01-01')), 'Domingo', 'Lunes', 'Martes', 'Miércoles',
                      'Jueves', 'Viernes', 'Sábado'),
               CASE WHEN DATEPART(WEEKDAY, DATEADD(DAY, i, '2019-01-01')) IN (1, 7) THEN 1 ELSE 0 END
        FROM n;
    END
GO

/* DimAeropuerto */
IF OBJECT_ID('dbo.DimAeropuerto') IS NULL
CREATE TABLE dbo.DimAeropuerto
(
    AeropuertoKey      INT IDENTITY (-1,1) PRIMARY KEY,
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
    Latitud            DECIMAL(11, 7),
    Longitud           DECIMAL(11, 7),
    ElevationFt        INT,
    TipoAeropuerto     VARCHAR(50),
    ServicioProgramado VARCHAR(30),
    ZonaHoraria        VARCHAR(50),
    OrigenFuente       VARCHAR(12) NOT NULL DEFAULT 'OurAirports'
);
CREATE UNIQUE INDEX UX_DimAeropuerto_ICAO ON dbo.DimAeropuerto (ICAO)
    WHERE ICAO IS NOT NULL;
GO

/* DimAerolínea */
IF OBJECT_ID('dbo.DimAerolinea') IS NULL
CREATE TABLE dbo.DimAerolinea
(
    AerolineaKey INT IDENTITY (-1,1) PRIMARY KEY,
    BK_AirlineID INT NOT NULL UNIQUE,
    Nombre       NVARCHAR(200),
    Alias        NVARCHAR(200),
    IATA         VARCHAR(5),
    ICAO         VARCHAR(4),
    Callsign     VARCHAR(50),
    Pais         NVARCHAR(100),
    Activa       VARCHAR(2)
);
CREATE UNIQUE INDEX UX_DimAerolinea_ICAO ON dbo.DimAerolinea (ICAO) WHERE ICAO IS NOT NULL;
GO

/* DimAvion */
IF OBJECT_ID('dbo.DimAvion') IS NULL
CREATE TABLE dbo.DimAvion
(
    AvionKey       INT IDENTITY (-1,1) PRIMARY KEY,
    BK_CodigoTipo  VARCHAR(30) NOT NULL UNIQUE,
    OrigenRegistro VARCHAR(20)
);
GO

/* FactVuelos */
IF OBJECT_ID('dbo.FactVuelos') IS NULL
CREATE TABLE dbo.FactVuelos
(
    VueloKey                BIGINT IDENTITY (1,1) PRIMARY KEY,
    FechaKey                INT          NOT NULL REFERENCES dbo.DimFecha (FechaKey),
    HoraSalida              TINYINT      NOT NULL,
    AerolineaKey            INT          NOT NULL REFERENCES dbo.DimAerolinea (AerolineaKey),
    AvionKey                INT          NOT NULL REFERENCES dbo.DimAvion (AvionKey),
    AeropuertoOrigenKey     INT          NOT NULL REFERENCES dbo.DimAeropuerto (AeropuertoKey),
    AeropuertoDestinoKey    INT          NOT NULL REFERENCES dbo.DimAeropuerto (AeropuertoKey),
    Callsign                VARCHAR(20),
    AircraftUID             VARCHAR(40),
    PrimeraVista            DATETIME2(0) NOT NULL,
    UltimaVista             DATETIME2(0) NOT NULL,
    CantidadVuelos          INT          NOT NULL DEFAULT 1,
    DuracionMinutos         INT,
    DistanciaKm             DECIMAL(10, 2),
    EsInternacional         BIT,
    EsRutaOfertada          BIT,
    AsientosDisponibles     INT,
    PasajerosEstimados      INT,
    FactorOcupacionEstimado DECIMAL(5, 4),
    IngresoEstimadoUSD      DECIMAL(12, 2),
    RetrasoEstimadoMin      INT,
    CONSTRAINT UQ_FactVuelos UNIQUE (AircraftUID, PrimeraVista)
);
GO

/* AQUI HACEMOS EL CROSSWALK DE RUTAS (OPENFLIGHTS
   PRE-CALCULAR PARES DE ICAO ORIGEN-DESTINO UNA VEZ
   POR CARGA PARA QUE ESRUTAOFERTADA SEA UN EQUI-JOIN RAPIDO SOBRE 2M DE FILAS*/

IF OBJECT_ID('dbo.xw_rutas_icao') IS NULL
CREATE TABLE dbo.xw_rutas_icao
(
    origen  VARCHAR(4) NOT NULL,
    destino VARCHAR(4) NOT NULL,
    CONSTRAINT PK_xw_rutas PRIMARY KEY (origen, destino)
);
GO

/* LOGO */
IF OBJECT_ID('dbo.LogCarga') IS NULL
CREATE TABLE dbo.LogCarga
(
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

/* ELEMENTOS -1 */
SET IDENTITY_INSERT dbo.DimAeropuerto ON;
INSERT INTO dbo.DimAeropuerto (AeropuertoKey, BK_Ident, Nombre, OrigenFuente)
VALUES (-1, 'DESCONOCIDO', N'Aeropuerto no catalogado', 'N/D');
SET IDENTITY_INSERT dbo.DimAeropuerto OFF;
SET IDENTITY_INSERT dbo.DimAerolinea ON;
INSERT INTO dbo.DimAerolinea (AerolineaKey, BK_AirlineID, Nombre, Activa)
VALUES (-1, -1, N'Aerolínea no identificada', 'ND');
SET IDENTITY_INSERT dbo.DimAerolinea OFF;
SET IDENTITY_INSERT dbo.DimAvion ON;
INSERT INTO dbo.DimAvion (AvionKey, BK_CodigoTipo, OrigenRegistro)
VALUES (-1, 'DESC', 'N/D');
SET IDENTITY_INSERT dbo.DimAvion OFF;
GO

/* CHEQUEOS */
SELECT (SELECT COUNT(*) FROM dbo.DimFecha)      AS dim_fecha,      -- debe ser 731
       (SELECT COUNT(*) FROM dbo.DimAeropuerto) AS dim_aeropuerto, -- debe ser 1 (el -1)
       (SELECT COUNT(*) FROM dbo.DimAerolinea)  AS dim_aerolinea,  -- debe ser 1
       (SELECT COUNT(*) FROM dbo.DimAvion)      AS dim_avion,      -- debe ser 1
       (SELECT COUNT(*) FROM dbo.FactVuelos)    AS hechos,         -- debe ser 0
       (SELECT COUNT(*) FROM dbo.xw_rutas_icao) AS xw_rutas,       -- debe ser 0
       (SELECT COUNT(*) FROM dbo.LogCarga)      AS logs; -- debe ser 0


