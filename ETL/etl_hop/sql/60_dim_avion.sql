/* 60 · DimAvion (equivale a DF_DimAvion).
   Codigos de tipo de avion vistos en OpenSky (typecode) y en el catalogo de rutas
   (equipment). OrigenRegistro dice de donde vino: OpenSky, Rutas o Ambos.

   RTRIM: el catalogo de rutas trae codigos con espacio al final (por ejemplo 717 con espacio).
   SQL Server ignora los espacios finales al comparar texto, asi que su DISTINCT los juntaba.
   PostgreSQL compara exacto y creaba 20 codigos duplicados. Se normaliza aqui. */
INSERT INTO dimavion (bk_codigotipo, origenregistro)
SELECT codigo, CASE WHEN COUNT(*) = 2 THEN 'Ambos' ELSE MAX(origen) END
FROM (
    SELECT DISTINCT RTRIM(typecode::VARCHAR(30)) AS codigo, 'OpenSky' AS origen
    FROM stg.os_flights
    WHERE NULLIF(RTRIM(typecode), '') IS NOT NULL AND typecode <> 'UNDEFINED'
    UNION
    SELECT DISTINCT RTRIM(equipment::VARCHAR(30)), 'Rutas'
    FROM stg.of_routes
    WHERE NULLIF(RTRIM(equipment), '') IS NOT NULL
) u
GROUP BY codigo
HAVING NOT EXISTS (SELECT 1 FROM dimavion d WHERE d.bk_codigotipo = codigo);
