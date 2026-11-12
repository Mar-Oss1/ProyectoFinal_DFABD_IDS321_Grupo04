/* ============================================================
   00 · STAGING + PARÁMETROS DE SIMULACIÓN (PostgreSQL)
   Equivalente de BD/00_stading.sql (SQL Server).
   Ejecutar UNA vez en la base openflightsdw, antes de la primera carga.
   RE-EJECUTABLE: SÍ (IF NOT EXISTS + ON CONFLICT).

   Quién llena estas tablas: el ETL de Apache Hop (pipelines CSV -> tabla),
   que las vacía (truncate) antes de cada carga. En SQL Server lo hacía
   BULK INSERT dentro del propio script.

   Diferencias con SQL Server (para la matriz comparativa):
   - Esquema propio "stg" en lugar del prefijo oa_stg_ / os_stg_ en dbo:
     separa físicamente los datos crudos del modelo dimensional.
   - Todas las columnas son TEXT: el staging guarda el dato TAL CUAL viene
     del archivo; la conversión de tipos ocurre en la transformación.
     (SQL Server usaba tipos y BULK INSERT con MAXERRORS, que descarta filas
     en silencio si un valor no cabe.)
   - OpenFlights se carga desde sus CSV (BD/datos_crudos/openflights/csv),
     no desde el respaldo OpenFlights.bak, que solo sirve en SQL Server.
   - Los nombres de columna son IGUALES a la cabecera de cada CSV, para que
     Hop los mapee solo.
   ============================================================ */

CREATE SCHEMA IF NOT EXISTS stg;

/* ---------- OurAirports (maestro de aeropuertos) ---------- */
CREATE TABLE IF NOT EXISTS stg.oa_airports (
    id TEXT, ident TEXT, type TEXT, name TEXT,
    latitude_deg TEXT, longitude_deg TEXT, elevation_ft TEXT,
    continent TEXT, iso_country TEXT, iso_region TEXT, municipality TEXT,
    scheduled_service TEXT, icao_code TEXT, iata_code TEXT, gps_code TEXT,
    local_code TEXT, home_link TEXT, wikipedia_link TEXT, keywords TEXT
);

CREATE TABLE IF NOT EXISTS stg.oa_regions (
    id TEXT, code TEXT, local_code TEXT, name TEXT,
    continent TEXT, iso_country TEXT, wikipedia_link TEXT, keywords TEXT
);

CREATE TABLE IF NOT EXISTS stg.oa_countries (
    id TEXT, code TEXT, name TEXT, continent TEXT,
    wikipedia_link TEXT, keywords TEXT
);

/* ---------- OpenSky (vuelos reales ADS-B, diciembre 2019) ---------- */
CREATE TABLE IF NOT EXISTS stg.os_flights (
    callsign TEXT, number TEXT, aircraft_uid TEXT, typecode TEXT,
    origin TEXT, destination TEXT, firstseen TEXT, lastseen TEXT, day TEXT,
    latitude_1 TEXT, longitude_1 TEXT, altitude_1 TEXT,
    latitude_2 TEXT, longitude_2 TEXT, altitude_2 TEXT
);

/* ---------- OpenFlights (catálogo de aerolíneas y rutas) ---------- */
CREATE TABLE IF NOT EXISTS stg.of_airports (
    airport_id TEXT, name TEXT, city TEXT, country TEXT, iata TEXT, icao TEXT,
    latitude TEXT, longitude TEXT, altitude_ft TEXT, utc_offset TEXT,
    dst TEXT, tz_olson TEXT, type TEXT, source TEXT
);

CREATE TABLE IF NOT EXISTS stg.of_airlines (
    airline_id TEXT, name TEXT, alias TEXT, iata TEXT, icao TEXT,
    callsign TEXT, country TEXT, active TEXT
);

CREATE TABLE IF NOT EXISTS stg.of_routes (
    route_id TEXT, airline_code TEXT, airline_id TEXT,
    source_airport TEXT, source_airport_id TEXT,
    dest_airport TEXT, dest_airport_id TEXT,
    codeshare TEXT, stops TEXT, equipment TEXT
);

CREATE TABLE IF NOT EXISTS stg.of_countries (
    name TEXT, iso_code TEXT, dafif_code TEXT
);

/* ---------- Parámetros de simulación (gobernanza de medidas estimadas) ----------
   Mismos valores que en SQL Server. MERGE -> INSERT ... ON CONFLICT DO UPDATE. */
CREATE TABLE IF NOT EXISTS parametrossimulacion (
    parametro   VARCHAR(50)   PRIMARY KEY,
    valor       NUMERIC(12,4) NOT NULL,
    descripcion VARCHAR(200)
);

INSERT INTO parametrossimulacion (parametro, valor, descripcion) VALUES
 ('AsientosPromedio',     180.0, 'Asientos base por vuelo simulado'),
 ('FactorOcupacionBase',  0.800, 'Ocupación base'),
 ('FactorEstacionalAlta', 0.050, 'Bono de ocupación meses ene/jul/dic'),
 ('JitterRango',          0.100, 'Rango de variación determinista'),
 ('TarifaUSDPorKm',       0.090, 'Ingreso estimado por pasajero-km'),
 ('RetrasoBaseMax',       35.0,  'Minutos máximos de retraso base'),
 ('RetrasoExtraPeak',     10.0,  'Minutos extra en horas pico 7-9 y 17-19')
ON CONFLICT (parametro) DO UPDATE
   SET valor = EXCLUDED.valor, descripcion = EXCLUDED.descripcion;

/* ---------- Chequeo ---------- */
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'stg' OR table_name = 'parametrossimulacion'
ORDER BY table_schema, table_name;
