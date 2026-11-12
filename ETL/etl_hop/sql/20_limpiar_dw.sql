/* 20 · Limpiar el DW antes de recargar (equivale a Limpiar las Dimensiones de SSIS).
   Los miembros -1 se conservan: son datos de diseño, no de carga. */
TRUNCATE TABLE factvuelos;
DELETE FROM dimaeropuerto WHERE aeropuertokey <> -1;
DELETE FROM dimaerolinea  WHERE aerolineakey  <> -1;
DELETE FROM dimavion      WHERE avionkey      <> -1;
