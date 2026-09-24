SELECT COUNT(*) AS pares_ruta FROM dbo.xw_rutas_icao;

SELECT COUNT(*) AS aviones FROM dbo.DimAvion;
SELECT TOP 5 BK_CodigoTipo, OrigenRegistro FROM dbo.DimAvion ORDER BY AvionKey DESC;