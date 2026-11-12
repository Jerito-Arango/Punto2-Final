-- Porcentaje de entregas exitosas por fecha y ciudad
-- 100 * exitosas / total de intentos (todos los estados en el denominador), sin división entera
SELECT
    fecha,
    ciudad,
    CAST(
        ROUND(
            100 * CAST(SUM(CASE WHEN estado = 'entregado' THEN 1 ELSE 0 END) AS DOUBLE)
                / CAST(COUNT(*) AS DOUBLE),
            2
        ) AS DECIMAL(5, 2)
    ) AS porcentaje_exito
FROM entregas_jero_db.entregas
WHERE fecha BETWEEN '2026-10-01' AND '2026-10-03'
GROUP BY fecha, ciudad
ORDER BY fecha ASC, ciudad ASC;
