-- 1) Los seis registros del 2026-10-03
SELECT
    fecha,
    id_envio,
    ciudad,
    transportadora,
    estado,
    duracion_minutos
FROM entregas_jero_db.entregas
WHERE fecha = '2026-10-03'
ORDER BY id_envio;

-- 2) Conteo por estado del 2026-10-03
SELECT
    fecha,
    estado,
    COUNT(*) AS total_intentos
FROM entregas_jero_db.entregas
WHERE fecha = '2026-10-03'
GROUP BY fecha, estado
ORDER BY estado;

-- 3) Total de registros de la tabla y registros por fecha
SELECT
    COUNT(*)                                             AS total_registros,
    COUNT(DISTINCT fecha)                                AS fechas_con_datos,
    SUM(CASE WHEN fecha = '2026-10-03' THEN 1 ELSE 0 END) AS registros_2026_10_03
FROM entregas_jero_db.entregas;
