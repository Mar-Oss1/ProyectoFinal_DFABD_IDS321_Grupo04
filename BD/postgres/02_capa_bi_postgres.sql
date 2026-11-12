/* ============================================================
   02 · CAPA ANALÍTICA (equivalente Open Source del cubo SSAS)
   Vistas SQL en el esquema bi que responden P1 a P8 y los 3 KPIs.
   Metabase lee estas vistas para el dashboard.
   RE-EJECUTABLE: SÍ (CREATE OR REPLACE VIEW).

   Cómo se corresponde con el cubo:
   - Medidas del cubo (Cantidad Vuelos, Distancia Km...)  -> SUM / COUNT en SQL.
   - Cálculos (% participación, promedios)                -> columnas calculadas.
   - KPIs (valor, objetivo, estado)                       -> columnas valor / meta / estado
                                                             con la misma regla del semáforo:
                                                             1 si valor >= meta, 0 si >= 80 % de la meta, -1 si no.
   - Jerarquías (Geografía, Calendario)                   -> columnas de cada nivel en
                                                             bi.v_vuelos, para agrupar y filtrar.
   ============================================================ */

CREATE SCHEMA IF NOT EXISTS bi;

/* ---------- Vista base: el hecho con todas sus dimensiones (modelo "aplanado") ---------- */
CREATE OR REPLACE VIEW bi.v_vuelos AS
SELECT f.vuelokey,
       -- Calendario
       df.fecha, df.anio, df.trimestre, df.mes, df.nombremes, df.dia,
       df.diasemana, df.nombredia, df.esfindesemana,
       -- Hora (UTC)
       dh.hora, dh.horautc,
       -- Aerolínea y avión
       al.nombre  AS aerolinea, al.icao AS aerolinea_icao, al.pais AS aerolinea_pais,
       av.bk_codigotipo AS avion,
       -- Geografía origen
       o.icao AS origen_icao, o.nombre AS origen_nombre, o.ciudad AS origen_ciudad,
       o.codigopais AS origen_codigopais, o.paisnombre AS origen_pais,
       o.regionnombre AS origen_region, o.continente AS origen_continente,
       o.tipoaeropuerto AS origen_tipo, o.servicioprogramado AS origen_servicio,
       -- Geografía destino
       d.icao AS destino_icao, d.nombre AS destino_nombre, d.ciudad AS destino_ciudad,
       d.codigopais AS destino_codigopais, d.paisnombre AS destino_pais,
       d.continente AS destino_continente,
       -- Banderas
       f.esinternacional, f.esrutaofertada,
       (f.aeropuertoorigenkey  = -1) AS origen_no_identificado,
       (f.aeropuertodestinokey = -1) AS destino_no_identificado,
       (f.aerolineakey = -1)         AS aerolinea_no_identificada,
       (f.avionkey = -1)             AS avion_no_identificado,
       -- Medidas
       f.cantidadvuelos, f.duracionminutos, f.distanciakm,
       f.asientosdisponibles, f.pasajerosestimados, f.factorocupacionestimado,
       f.ingresoestimadousd, f.retrasoestimadomin
FROM factvuelos f
JOIN dimfecha      df ON df.fechakey      = f.fechakey
JOIN dimhora       dh ON dh.hora          = f.horasalida
JOIN dimaerolinea  al ON al.aerolineakey  = f.aerolineakey
JOIN dimavion      av ON av.avionkey      = f.avionkey
JOIN dimaeropuerto o  ON o.aeropuertokey  = f.aeropuertoorigenkey
JOIN dimaeropuerto d  ON d.aeropuertokey  = f.aeropuertodestinokey;

/* ---------- KPIs y totales (P1, P3, P6, P7, P8 en una fila) ---------- */
CREATE OR REPLACE VIEW bi.v_kpis AS
WITH t AS (
    SELECT COUNT(*)                                                    AS vuelos,
           COUNT(*) FILTER (WHERE esrutaofertada)                      AS vuelos_ruta_ofertada,
           COUNT(*) FILTER (WHERE esinternacional)                     AS vuelos_internacionales,
           COUNT(*) FILTER (WHERE esinternacional IS NOT NULL)         AS vuelos_pais_conocido,
           COUNT(*) FILTER (WHERE aeropuertoorigenkey  = -1)           AS origen_no_id,
           COUNT(*) FILTER (WHERE aeropuertodestinokey = -1)           AS destino_no_id,
           COUNT(*) FILTER (WHERE aerolineakey = -1)                   AS aerolinea_no_id,
           COUNT(*) FILTER (WHERE avionkey = -1)                       AS avion_no_id,
           SUM(pasajerosestimados)                                     AS pasajeros,
           SUM(asientosdisponibles)                                    AS asientos,
           SUM(ingresoestimadousd)                                     AS ingreso,
           SUM(duracionminutos)                                        AS duracion,
           SUM(distanciakm)                                            AS distancia
    FROM factvuelos
),
k AS (
    SELECT t.*,
           vuelos_ruta_ofertada::NUMERIC / NULLIF(vuelos, 0)            AS kpi_rutas_valor,
           0.50                                                        AS kpi_rutas_meta,
           1 - origen_no_id::NUMERIC / NULLIF(vuelos, 0)               AS kpi_aeropuertos_valor,
           0.95                                                        AS kpi_aeropuertos_meta,
           1 - aerolinea_no_id::NUMERIC / NULLIF(vuelos, 0)            AS kpi_aerolineas_valor,
           0.70                                                        AS kpi_aerolineas_meta
    FROM t
)
SELECT vuelos,
       -- P1 · KPI Rutas Ofertadas
       ROUND(kpi_rutas_valor, 4) AS kpi_rutas_valor, kpi_rutas_meta,
       CASE WHEN kpi_rutas_valor >= kpi_rutas_meta THEN 1
            WHEN kpi_rutas_valor >= kpi_rutas_meta * 0.8 THEN 0 ELSE -1 END AS kpi_rutas_estado,
       -- P3 · % internacional (sobre vuelos con país conocido)
       vuelos_internacionales, vuelos_pais_conocido,
       vuelos_pais_conocido - vuelos_internacionales                      AS vuelos_nacionales,
       ROUND(vuelos_internacionales::NUMERIC / NULLIF(vuelos_pais_conocido, 0), 4) AS pct_internacional,
       -- P6 · promedios generales
       ROUND(duracion::NUMERIC / NULLIF(vuelos, 0), 1)                    AS duracion_promedio_min,
       -- P7 · simulados
       ROUND(pasajeros::NUMERIC / NULLIF(asientos, 0), 4)                 AS ocupacion_promedio_estimada,
       ROUND(ingreso / NULLIF(vuelos, 0), 2)                              AS ingreso_estimado_por_vuelo,
       -- P8 · calidad
       ROUND(origen_no_id::NUMERIC    / NULLIF(vuelos, 0), 4)             AS pct_origen_no_id,
       ROUND(destino_no_id::NUMERIC   / NULLIF(vuelos, 0), 4)             AS pct_destino_no_id,
       ROUND(aerolinea_no_id::NUMERIC / NULLIF(vuelos, 0), 4)             AS pct_aerolinea_no_id,
       ROUND(avion_no_id::NUMERIC     / NULLIF(vuelos, 0), 4)             AS pct_avion_no_id,
       -- KPI Identificación Aeropuertos
       ROUND(kpi_aeropuertos_valor, 4) AS kpi_aeropuertos_valor, kpi_aeropuertos_meta,
       CASE WHEN kpi_aeropuertos_valor >= kpi_aeropuertos_meta THEN 1
            WHEN kpi_aeropuertos_valor >= kpi_aeropuertos_meta * 0.8 THEN 0 ELSE -1 END AS kpi_aeropuertos_estado,
       -- KPI Identificación Aerolíneas
       ROUND(kpi_aerolineas_valor, 4) AS kpi_aerolineas_valor, kpi_aerolineas_meta,
       CASE WHEN kpi_aerolineas_valor >= kpi_aerolineas_meta THEN 1
            WHEN kpi_aerolineas_valor >= kpi_aerolineas_meta * 0.8 THEN 0 ELSE -1 END AS kpi_aerolineas_estado
FROM k;

/* ---------- P2 · Tráfico por continente / país / región de origen ---------- */
CREATE OR REPLACE VIEW bi.v_p2_geografia AS
SELECT origen_continente AS continente, origen_pais AS pais, origen_region AS region,
       COUNT(*) AS vuelos,
       ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (), 6) AS pct_trafico
FROM bi.v_vuelos
GROUP BY origen_continente, origen_pais, origen_region;

/* ---------- P3 · Nacional vs internacional por país de origen ---------- */
CREATE OR REPLACE VIEW bi.v_p3_pais AS
SELECT origen_pais AS pais,
       COUNT(*)                                          AS vuelos,
       COUNT(*) FILTER (WHERE esinternacional IS NOT NULL) AS vuelos_pais_conocido,
       COUNT(*) FILTER (WHERE esinternacional)           AS internacionales,
       COUNT(*) FILTER (WHERE NOT esinternacional)       AS nacionales,
       ROUND(COUNT(*) FILTER (WHERE esinternacional)::NUMERIC
             / NULLIF(COUNT(*) FILTER (WHERE esinternacional IS NOT NULL), 0), 4) AS pct_internacional
FROM bi.v_vuelos
GROUP BY origen_pais;

/* ---------- P4 · Aerolíneas y tipos de avión ---------- */
CREATE OR REPLACE VIEW bi.v_p4_aerolineas AS
SELECT aerolinea, aerolinea_icao, COUNT(*) AS vuelos,
       ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (), 4) AS pct_participacion
FROM bi.v_vuelos GROUP BY aerolinea, aerolinea_icao;

CREATE OR REPLACE VIEW bi.v_p4_aviones AS
SELECT avion, COUNT(*) AS vuelos,
       ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (), 4) AS pct_participacion
FROM bi.v_vuelos GROUP BY avion;

/* ---------- P5 · Patrones temporales ---------- */
CREATE OR REPLACE VIEW bi.v_p5_hora AS
SELECT hora, horautc, COUNT(*) AS vuelos,
       ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (), 4) AS pct_vuelos
FROM bi.v_vuelos GROUP BY hora, horautc;

-- Promedio por día: divide entre los días CON datos (igual que NONEMPTY en el cubo),
-- así el sábado 14, ausente en OpenSky, no cuenta como un día con cero vuelos.
CREATE OR REPLACE VIEW bi.v_p5_dia_semana AS
SELECT diasemana, nombredia, esfindesemana,
       COUNT(*)               AS vuelos,
       COUNT(DISTINCT fecha)  AS dias_con_datos,
       ROUND(COUNT(*)::NUMERIC / COUNT(DISTINCT fecha), 1) AS promedio_vuelos_por_dia
FROM bi.v_vuelos GROUP BY diasemana, nombredia, esfindesemana;

CREATE OR REPLACE VIEW bi.v_p5_fecha AS
SELECT df.fecha, df.nombredia, df.esfindesemana,
       COUNT(f.vuelokey) AS vuelos,
       CASE df.fecha WHEN DATE '2019-12-24' THEN 'Nochebuena'
                     WHEN DATE '2019-12-25' THEN 'Navidad'
                     WHEN DATE '2019-12-31' THEN 'Fin de Año' END AS festivo
FROM dimfecha df
LEFT JOIN factvuelos f ON f.fechakey = df.fechakey
WHERE df.fecha BETWEEN DATE '2019-12-01' AND DATE '2019-12-31'
GROUP BY df.fecha, df.nombredia, df.esfindesemana;

/* ---------- P6 y P7 · Rutas: distancia, duración, pasajeros e ingresos ---------- */
CREATE OR REPLACE VIEW bi.v_rutas AS
SELECT origen_icao, destino_icao,
       origen_icao || ' → ' || destino_icao      AS ruta,
       origen_ciudad, destino_ciudad, origen_pais, destino_pais,
       COUNT(*)                                   AS vuelos,
       MAX(distanciakm)                           AS distancia_km,
       ROUND(AVG(duracionminutos), 0)             AS duracion_promedio_min,
       SUM(pasajerosestimados)                    AS pasajeros_estimados,
       SUM(ingresoestimadousd)                    AS ingreso_estimado_usd,
       ROUND(SUM(pasajerosestimados)::NUMERIC / NULLIF(SUM(asientosdisponibles), 0), 4) AS ocupacion_estimada,
       ROUND(SUM(ingresoestimadousd) / COUNT(*), 2) AS ingreso_estimado_por_vuelo
FROM bi.v_vuelos
WHERE NOT origen_no_identificado AND NOT destino_no_identificado
  AND origen_icao <> destino_icao
GROUP BY origen_icao, destino_icao, origen_ciudad, destino_ciudad, origen_pais, destino_pais;

/* ---------- Chequeo ---------- */
SELECT * FROM bi.v_kpis;
