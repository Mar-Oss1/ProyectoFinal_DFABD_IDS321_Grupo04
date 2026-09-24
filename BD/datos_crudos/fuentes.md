# Fuentes de datos · Proyecto Final DFABD IDS321 · Grupo 04

> **Propósito de este archivo:** los archivos crudos de gran tamaño (CSV/GZ/DAT/BAK)
> **NO se versionan en GitHub** (superan límites de peso y son re-descargables).
> Este documento registra origen, licencia, fecha y verificación de cada archivo,
> de modo que cualquier persona pueda reconstruir `datos_crudos/` y repetir el
> pipeline completo del proyecto.

---

## 1. OpenFlights · Rutas, aeropuertos, aerolíneas y aviones

| | |
|---|---|
| Proyecto | OpenFlights.org · repositorio oficial de datos |
| URL del proyecto | https://openflights.org/data.html |
| Repositorio | https://github.com/jpatokal/openflights |
| Licencia | **ODbL** (Open Database License) |
| Uso en el proyecto | Capa OLTP (`OpenFlights` en SQL Server): dimensiones de aerolíneas y aviones, zona horaria, complemento de aeropuertos y oferta de rutas (`xw_rutas_icao`) |

**Archivos originales (.dat):**

| Archivo | URL directa | Registros en OLTP |
|---|---|---|
| airports.dat | https://raw.githubusercontent.com/jpatokal/openflights/master/data/airports.dat | 7,698 |
| airlines.dat | https://raw.githubusercontent.com/jpatokal/openflights/master/data/airlines.dat | 6,162 |
| routes.dat | https://raw.githubusercontent.com/jpatokal/openflights/master/data/routes.dat | 67,663 |
| planes.dat | https://raw.githubusercontent.com/jpatokal/openflights/master/data/planes.dat | 246 |
| countries.dat | https://raw.githubusercontent.com/jpatokal/openflights/master/data/countries.dat | 261 |

**Nota de trazabilidad:** el equipo no trabaja sobre los `.dat` directamente, sino sobre la
base OLTP `OpenFlights` construida el 22/09/2026 con el script generado por el equipo
(`openflights.sql`, distribuido como `OpenFlights.bak`), que aplica la limpieza
documentada: `\N` → NULL, valores basura (`''`, `'-'`, `'N/A'`) → NULL, y conservación de
códigos con FK en NULL para ~530 rutas con aeropuerto inexistente (0 violaciones de FK).

**Citación:** OpenFlights.org, datos bajo licencia ODbL.

---

## 2. OurAirports · Maestro mundial de aeropuertos, regiones y países

| | |
|---|---|
| URL del proyecto | https://ourairports.com/data/ |
| Licencia | **Dominio público** |
| Fecha de descarga | 22/09/2026 |
| Uso en el proyecto | Dimensión maestra `DimAeropuerto` (staging `oa_stg_*`): cobertura mundial, continente, tipo de aeropuerto, región y país |

**Archivos descargados:**

| Archivo | URL directa | Registros cargados en staging |
|---|---|---|
| airports.csv | https://ourairports.com/data/airports.csv | 258,348 |
| regions.csv | https://ourairports.com/data/regions.csv | 11,961 |
| countries.csv | https://ourairports.com/data/countries.csv | 747 |

**Archivos disponibles no utilizados en esta iteración** (candidates para futuras mejoras):
`runways.csv`, `navaids.csv`, `airport-frequencies.csv`, `airlines.csv` (mismas URLs base).

**Citación:** OurAirports.com, datos de dominio público.

---

## 3. OpenSky Network · Vuelos reales ADS-B (tabla de hechos)

| | |
|---|---|
| Registro de datos | https://zenodo.org/records/5815448 |
| Licencia | **CC-BY** (cobertura con esta licencia hasta enero 2022) |
| Fecha de descarga | 22/09/2026 |
| Uso en el proyecto | Tabla de hechos `FactVuelos` (staging `os_stg_flights`): un vuelo real por fila |

**Archivo descargado:**

| Archivo | Contenido | Registros cargados en staging |
|---|---|---|
| `flightlist_20191201_20191231.csv.gz` → descomprimido a `flightlist_20191201_20191231.csv` | Vuelos ADS-B de diciembre 2019 (mes completo) | 2,701,295 |

**Notas técnicas:**
- El registro de Zenodo publica **un archivo por mes** con el patrón
  `flightlist_YYYYMMDD_YYYYMMDD.csv.gz`; se eligió diciembre 2019 por ser tráfico
  pre-pandemia con pico estacional visible.
- El checksum MD5 de cada archivo está publicado en la página del registro para verificación.
- El archivo viene comprimido (gzip): descomprimir antes de la carga BULK INSERT.

**Citación obligatoria (CC-BY):** *OpenSky Network* (https://opensky-network.org),
dataset publicado en Zenodo, registro 5815448.

---

## 4. Reproducibilidad del pipeline (cómo reconstruir todo desde cero)

1. Descargar los archivos de las secciones 1 a 3 en `datos_crudos/` (subcarpetas
   `openflights/`, `ourairports/`, `opensky/`).
2. Descomprimir `flightlist_20191201_20191231.csv.gz`.
3. Copiar los CSV de OurAirports y OpenSky a la carpeta local de trabajo `C:\datos_dw\`
   (decisión B-04: la cuenta de servicio de SQL Server no lee carpetas sincronizadas de Onedrive).
4. Restaurar/crear la capa OLTP `OpenFlights` (script `openflights_sqlserver.sql` o `OpenFlights.bak`).
5. Ejecutar `microsoft/sql_server/00_staging.sql` (staging + perfil + cobertura).
6. Ejecutar `microsoft/sql_server/01_crear_dw.sql` (esquema estrella).
7. Ejecutar el paquete SSIS `microsoft/etl_ssis/` (carga de dimensiones y hechos).
8. Verificar conteos contra los valores de las tablas de este documento.

---

## 5. Resumen de licencias y citaciones

| Fuente | Licencia | Citación requerida |
|---|---|---|
| OpenFlights | ODbL | Sí: OpenFlights.org |
| OurAirports | Dominio público | Recomendada: OurAirports.com |
| OpenSky Network | CC-BY | Sí: OpenSky Network + registro Zenodo 5815448 |

*Documento mantenido por el Grupo 04 · IDS321 · última actualización: 23/09/2026.*
