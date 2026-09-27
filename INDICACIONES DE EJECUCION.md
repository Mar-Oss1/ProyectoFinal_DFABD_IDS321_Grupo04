# Indicaciones de ejecución

1. Restaurar `OpenFlights.bak` → fuente OLTP (una vez)
2. Ejecutar `00_staging.sql` → esperar 86,116 / 3,987 / 249 / 2,700,968
3. Ejecutar `01_crear_dw.sql` → esperar 731 / 1 / 1 / 1 / 0 / 0 / 0
4. Ejecutar `ETL/etl_ssis/Package.dtsx` → esperar LogCarga `OK-SSIS`
5. Ejecutar `02_validaciones.sql` → capturar resultados como evidencia

**NADA MÁS se ejecuta.** Cualquier otro `.sql` es histórico o análisis futuro.
