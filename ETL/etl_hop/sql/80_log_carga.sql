/* 80 · Registro de la carga (equivale a SQL_LOG). Evidencia de ejecución del ETL. */
INSERT INTO logcarga (inicio, fin, filasdimaeropuerto, filasdimaerolinea,
                      filasdimavion, filasfactvuelos, estado)
VALUES (NOW(), NOW(),
        (SELECT COUNT(*) FROM dimaeropuerto WHERE aeropuertokey <> -1),
        (SELECT COUNT(*) FROM dimaerolinea  WHERE aerolineakey  <> -1),
        (SELECT COUNT(*) FROM dimavion      WHERE avionkey      <> -1),
        (SELECT COUNT(*) FROM factvuelos),
        'OK-HOP');
