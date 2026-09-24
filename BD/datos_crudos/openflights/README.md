# OpenFlights — Base de datos

Extracción completa de los datos abiertos de [OpenFlights](https://openflights.org)
convertidos a una base de datos relacional normalizada.

Fuente: `https://github.com/jpatokal/openflights` (carpeta `data/`), snapshot descargado
desde `raw.githubusercontent.com`.

## Contenido

| Archivo | Descripción |
|---|---|
| `openflights.db` | Base SQLite lista para usar (PK, FK e índices ya creados) |
| `schema_postgresql.sql` | DDL para PostgreSQL / Supabase |
| `csv/*.csv` | Datos limpios con cabecera (`\N` → NULL), para importar donde quieras |
| `data/*.dat` | Archivos originales sin tocar (por si quieres re-procesar) |
| `build_db.py` | Script ETL que reconstruye todo desde los `.dat` |

## Totales

| Tabla | Filas |
|---|---|
| countries | 261 |
| airports | 7,698 |
| airlines | 6,162 |
| planes | 246 |
| routes | 67,663 |

## Esquema

- **countries** (`name`, `iso_code`, `dafif_code`)
- **airports** (`airport_id` PK, `name`, `city`, `country`, `iata`, `icao`,
  `latitude`, `longitude`, `altitude_ft`, `utc_offset`, `dst`, `tz_olson`, `type`, `source`)
- **airlines** (`airline_id` PK, `name`, `alias`, `iata`, `icao`, `callsign`,
  `country`, `active`)
- **planes** (`plane_id` PK, `name`, `iata`, `icao`)
- **routes** (`route_id` PK, `airline_code`, `airline_id` → airlines,
  `source_airport` / `source_airport_id` → airports,
  `dest_airport` / `dest_airport_id` → airports,
  `codeshare`, `stops`, `equipment`)

### Notas de integridad
- Los valores `\N` de OpenFlights se cargaron como `NULL`.
- En `routes`, ~263 IDs de aeropuerto origen y ~267 de destino apuntan a
  aeropuertos que no existen en `airports.dat` (datos incompletos de la fuente).
  Esos `*_airport_id` se dejaron en `NULL` para no romper las FK, **pero se
  conserva el código IATA/ICAO** en `source_airport` / `dest_airport`.
- `PRAGMA foreign_key_check` → 0 violaciones.

## Cómo usarla

### SQLite (inmediato)
```bash
sqlite3 openflights.db
SELECT name, iata, icao FROM airports WHERE country = 'El Salvador';
```

### PostgreSQL / Supabase
```bash
psql "postgres://USER:PASS@HOST:5432/postgres" -f schema_postgresql.sql
\copy countries FROM 'csv/countries.csv' CSV HEADER
\copy airports  FROM 'csv/airports.csv'  CSV HEADER
\copy airlines  FROM 'csv/airlines.csv'  CSV HEADER
\copy planes    FROM 'csv/planes.csv'    CSV HEADER
\copy routes    FROM 'csv/routes.csv'    CSV HEADER
```
En el dashboard de Supabase también puedes ir a *Table Editor → Import data*
y subir cada CSV (respeta el orden: primero los padres, `routes` al final).

### Reconstruir desde cero
```bash
python3 build_db.py   # regenera openflights.db y csv/ desde data/*.dat
```

## Licencia de los datos

Los datos de aeropuertos, aerolíneas y rutas de OpenFlights se publican bajo la
**Open Database License (ODbL)**. Si los usas o redistribuyes, atribuye a
OpenFlights y mantén la misma licencia para las bases derivadas.
Para cobertura más amplia de pistas/helipuertos existe también
[OurAirports](https://ourairports.com) (dominio público).

> El snapshot de GitHub es una copia estática que se actualiza esporádicamente;
> no es un feed en tiempo real.
