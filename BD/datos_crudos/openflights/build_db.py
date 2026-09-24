#!/usr/bin/env python3
"""
OpenFlights -> Base de datos relacional
Parsea los .dat de OpenFlights y genera:
  - openflights.db        (SQLite listo para usar, con PK/FK/indices)
  - csv/*.csv             (CSV limpios con cabecera, \\N -> vacio/NULL)
Estructura basada en la documentacion oficial de OpenFlights.
"""
import csv, sqlite3, os

DATA = "data"
CSVOUT = "csv"
os.makedirs(CSVOUT, exist_ok=True)

def rd(path):
    """Lee un .dat de OpenFlights. Comillas dobles, \\N = NULL."""
    with open(os.path.join(DATA, path), newline="", encoding="utf-8") as f:
        for row in csv.reader(f, quotechar='"', skipinitialspace=True):
            if not row:
                continue
            yield [None if c == r"\N" else c for c in row]

def to_int(v):
    try: return int(v) if v not in (None, "") else None
    except ValueError: return None

def to_float(v):
    try: return float(v) if v not in (None, "") else None
    except ValueError: return None

def to_bool(v):
    if v in (None, ""): return None
    return 1 if str(v).strip().upper() in ("Y", "YES", "TRUE", "1") else 0

# ---------- conexion ----------
if os.path.exists("openflights.db"):
    os.remove("openflights.db")
con = sqlite3.connect("openflights.db")
con.execute("PRAGMA foreign_keys = ON")
cur = con.cursor()

# ---------- esquema ----------
cur.executescript("""
CREATE TABLE countries (
  name       TEXT NOT NULL,
  iso_code   TEXT,          -- ISO 3166-1 alfa-2
  dafif_code TEXT
);

CREATE TABLE airports (
  airport_id  INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,
  city        TEXT,
  country     TEXT,
  iata        TEXT,          -- 3 letras
  icao        TEXT,          -- 4 letras
  latitude    REAL,
  longitude   REAL,
  altitude_ft INTEGER,
  utc_offset  REAL,          -- horas respecto a UTC
  dst         TEXT,          -- E/A/S/O/Z/N/U
  tz_olson    TEXT,          -- ej. America/El_Salvador
  type        TEXT,
  source      TEXT
);

CREATE TABLE airlines (
  airline_id INTEGER PRIMARY KEY,
  name       TEXT NOT NULL,
  alias      TEXT,
  iata       TEXT,           -- 2 caracteres
  icao       TEXT,           -- 3 letras
  callsign   TEXT,
  country    TEXT,
  active     INTEGER         -- 1=activa (Y), 0=inactiva (N)
);

CREATE TABLE planes (
  plane_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name     TEXT NOT NULL,
  iata     TEXT,
  icao     TEXT
);

CREATE TABLE routes (
  route_id            INTEGER PRIMARY KEY AUTOINCREMENT,
  airline_code        TEXT,     -- codigo IATA/ICAO tal cual viene
  airline_id          INTEGER,  -- FK a airlines (NULL si huerfano)
  source_airport      TEXT,
  source_airport_id   INTEGER,  -- FK a airports
  dest_airport        TEXT,
  dest_airport_id     INTEGER,  -- FK a airports
  codeshare           INTEGER,  -- 1 si es codeshare
  stops               INTEGER,
  equipment           TEXT,     -- codigos de avion separados por espacio
  FOREIGN KEY (airline_id)        REFERENCES airlines(airline_id),
  FOREIGN KEY (source_airport_id) REFERENCES airports(airport_id),
  FOREIGN KEY (dest_airport_id)   REFERENCES airports(airport_id)
);
""")

# ---------- carga countries ----------
countries = [(r[0], r[1], r[2]) for r in rd("countries.dat")]
cur.executemany("INSERT INTO countries VALUES (?,?,?)", countries)

# ---------- carga airports ----------
airport_ids = set()
airports = []
for r in rd("airports.dat"):
    aid = to_int(r[0]); airport_ids.add(aid)
    airports.append((aid, r[1], r[2], r[3], r[4], r[5],
                     to_float(r[6]), to_float(r[7]), to_int(r[8]),
                     to_float(r[9]), r[10], r[11], r[12], r[13]))
cur.executemany("INSERT INTO airports VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", airports)

# ---------- carga airlines ----------
airline_ids = set()
airlines = []
for r in rd("airlines.dat"):
    aid = to_int(r[0]); airline_ids.add(aid)
    airlines.append((aid, r[1], r[2], r[3], r[4], r[5], r[6], to_bool(r[7])))
cur.executemany("INSERT INTO airlines VALUES (?,?,?,?,?,?,?,?)", airlines)

# ---------- carga planes ----------
planes = [(r[0], r[1], r[2]) for r in rd("planes.dat")]
cur.executemany("INSERT INTO planes (name, iata, icao) VALUES (?,?,?)", planes)

# ---------- carga routes (respetando integridad: FK huerfana -> NULL) ----------
orph_al = orph_src = orph_dst = 0
routes = []
for r in rd("routes.dat"):
    al_id  = to_int(r[1])
    src_id = to_int(r[3])
    dst_id = to_int(r[5])
    if al_id  is not None and al_id  not in airline_ids: orph_al  += 1; al_id  = None
    if src_id is not None and src_id not in airport_ids: orph_src += 1; src_id = None
    if dst_id is not None and dst_id not in airport_ids: orph_dst += 1; dst_id = None
    routes.append((r[0], al_id, r[2], src_id, r[4], dst_id,
                   1 if r[6] == "Y" else 0, to_int(r[7]), r[8]))
cur.executemany("""INSERT INTO routes
  (airline_code, airline_id, source_airport, source_airport_id,
   dest_airport, dest_airport_id, codeshare, stops, equipment)
  VALUES (?,?,?,?,?,?,?,?,?)""", routes)

# ---------- indices utiles ----------
cur.executescript("""
CREATE INDEX idx_airports_iata     ON airports(iata);
CREATE INDEX idx_airports_icao     ON airports(icao);
CREATE INDEX idx_airports_country  ON airports(country);
CREATE INDEX idx_airlines_iata     ON airlines(iata);
CREATE INDEX idx_airlines_country  ON airlines(country);
CREATE INDEX idx_routes_src        ON routes(source_airport_id);
CREATE INDEX idx_routes_dst        ON routes(dest_airport_id);
CREATE INDEX idx_routes_airline    ON routes(airline_id);
""")
con.commit()

# ---------- exportar CSV limpios ----------
def dump_csv(table, filename):
    cols = [c[1] for c in cur.execute(f"PRAGMA table_info({table})")]
    rows = cur.execute(f"SELECT * FROM {table}").fetchall()
    with open(os.path.join(CSVOUT, filename), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(rows)
    return len(rows)

counts = {t: dump_csv(t, t + ".csv")
          for t in ("countries", "airports", "airlines", "planes", "routes")}

# ---------- verificacion FK ----------
fk_viol = cur.execute("PRAGMA foreign_key_check").fetchall()

print("=== Filas cargadas ===")
for t, n in counts.items():
    print(f"  {t:10} {n:>6}")
print(f"\nRutas con FK huerfana convertida a NULL:")
print(f"  aerolinea inexistente: {orph_al}")
print(f"  aeropuerto origen inexistente: {orph_src}")
print(f"  aeropuerto destino inexistente: {orph_dst}")
print(f"\nViolaciones de FK tras carga: {len(fk_viol)} (debe ser 0)")

con.close()
print("\nOK -> openflights.db + csv/*.csv")
