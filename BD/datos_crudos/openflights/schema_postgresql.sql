-- ============================================================
-- OpenFlights -> PostgreSQL / Supabase
-- Esquema listo para importar los CSV de la carpeta csv/
-- ============================================================
-- Uso rapido (psql local):
--   psql -f schema_postgresql.sql "postgres://..."
--   \copy countries FROM 'csv/countries.csv' CSV HEADER
--   \copy airports  FROM 'csv/airports.csv'  CSV HEADER
--   \copy airlines  FROM 'csv/airlines.csv'  CSV HEADER
--   \copy planes    FROM 'csv/planes.csv'    CSV HEADER
--   \copy routes    FROM 'csv/routes.csv'    CSV HEADER
--
-- En Supabase: crea las tablas con este script en el SQL Editor
-- y luego sube cada CSV desde Table Editor > Import data,
-- o usa \copy via connection string (recomendado para routes).
-- Importa en este orden (padres antes que routes) por las FK.
-- ============================================================

DROP TABLE IF EXISTS routes CASCADE;
DROP TABLE IF EXISTS planes CASCADE;
DROP TABLE IF EXISTS airlines CASCADE;
DROP TABLE IF EXISTS airports CASCADE;
DROP TABLE IF EXISTS countries CASCADE;

CREATE TABLE countries (
  name       TEXT NOT NULL,
  iso_code   TEXT,            -- ISO 3166-1 alfa-2
  dafif_code TEXT
);

CREATE TABLE airports (
  airport_id  INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,
  city        TEXT,
  country     TEXT,
  iata        TEXT,           -- 3 letras (NULL si no tiene)
  icao        TEXT,           -- 4 letras
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  altitude_ft INTEGER,
  utc_offset  REAL,           -- horas respecto a UTC
  dst         TEXT,           -- E/A/S/O/Z/N/U
  tz_olson    TEXT,           -- ej. America/El_Salvador
  type        TEXT,
  source      TEXT
);

CREATE TABLE airlines (
  airline_id INTEGER PRIMARY KEY,
  name       TEXT NOT NULL,
  alias      TEXT,
  iata       TEXT,            -- 2 caracteres
  icao       TEXT,            -- 3 letras
  callsign   TEXT,
  country    TEXT,
  active     BOOLEAN          -- true = Y
);

CREATE TABLE planes (
  plane_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name     TEXT NOT NULL,
  iata     TEXT,
  icao     TEXT
);

CREATE TABLE routes (
  route_id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  airline_code      TEXT,
  airline_id        INTEGER REFERENCES airlines(airline_id),
  source_airport    TEXT,
  source_airport_id INTEGER REFERENCES airports(airport_id),
  dest_airport      TEXT,
  dest_airport_id   INTEGER REFERENCES airports(airport_id),
  codeshare         BOOLEAN,
  stops             INTEGER,
  equipment         TEXT
);

-- Indices
CREATE INDEX idx_airports_iata    ON airports(iata);
CREATE INDEX idx_airports_icao    ON airports(icao);
CREATE INDEX idx_airports_country ON airports(country);
CREATE INDEX idx_airlines_iata    ON airlines(iata);
CREATE INDEX idx_airlines_country ON airlines(country);
CREATE INDEX idx_routes_src       ON routes(source_airport_id);
CREATE INDEX idx_routes_dst       ON routes(dest_airport_id);
CREATE INDEX idx_routes_airline   ON routes(airline_id);

-- Nota: si importas routes con GENERATED ALWAYS y el CSV trae route_id,
-- usa una columna temporal o cambia a "BY DEFAULT". El CSV incluye route_id,
-- asi que la variante mas comoda es:
--   ALTER TABLE routes ALTER COLUMN route_id DROP IDENTITY;   -- si diera conflicto
-- o importar el CSV sin la columna route_id.
