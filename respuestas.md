# Respuestas

## 1. ¿Por qué se pudo consultar el tercer día sin registrar una partición nueva?

Porque la tabla no depende de particiones guardadas en el catálogo, sino de las reglas de *partition projection* definidas en Terraform (`infraestructura/principal.tf`). En vez de ir al Glue Data Catalog a buscar qué particiones existen, Athena las calcula en cada consulta con las propiedades de la tabla. `projection.fecha.type = date`, formato `yyyy-MM-dd`, rango `2026-10-01,2026-10-03` e intervalo de 1 día generan las fechas 01, 02 y 03. La plantilla `storage.location.template` convierte cada fecha en el prefijo `s3://<bucket>/entregas/fecha=<fecha>/`.

El rango incluía el 3 de octubre desde el despliegue inicial. En la etapa inicial ese prefijo estaba vacío y por eso solo se contaban 12 registros. Al subir `entregas.csv` a `entregas/fecha=2026-10-03/`, la siguiente consulta encontró el objeto en la ubicación calculada. Sin crawlers, `MSCK REPAIR TABLE`, `ALTER TABLE ADD PARTITION` ni cambios en Terraform, la tabla pasó a 18 registros: los 6 del día 3 aparecen en `resultados/final/verificacion_tercer_dia.csv` y en los resultados finales de intentos y porcentaje (ver los ids de ejecución en `evidencias/ejecuciones_athena.csv`).

## 2. Si se subiera un archivo para el 4 de octubre con la configuración actual, ¿qué pasaría y qué habría que modificar?

Athena no mostraría esos registros. El archivo existiría en `s3://<bucket>/entregas/fecha=2026-10-04/entregas.csv`, pero el rango proyectado termina en `2026-10-03`, así que Athena nunca generaría la partición `2026-10-04` ni leería ese prefijo. La consulta no daría error: el total seguiría en 18 y un filtro `WHERE fecha = '2026-10-04'` devolvería cero filas. La proyección solo considera fechas dentro del rango, aunque haya archivos en S3.

Para incluirlo hay que ampliar el rango en Terraform, por ejemplo con `fecha_fin = "2026-10-04"` (lo que deja `projection.fecha.range = "2026-10-01,2026-10-04"`), y aplicar con `terraform apply`. No hace falta registrar particiones. Otra opción es usar un final relativo como `2026-10-01,NOW` para que nuevas fechas entren automáticamente. Si las consultas tienen un filtro de fechas fijo, como el `BETWEEN` de las consultas agregadas, también habría que ampliarlo.
