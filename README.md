# Examen final – Entregas con S3, Glue (partition projection) y Athena

Arquitectura: CSV locales → S3 (`entregas/`) → tabla externa en Glue Data Catalog con *partition projection* → Athena (workgroup) → resultados en S3 (`resultados-athena/`). Toda la infraestructura se define con Terraform en `infraestructura/`.

## Prerrequisitos

- Terraform ≥ 1.5 y AWS CLI v2 instalados.
- Credenciales de AWS configuradas localmente (`aws configure` o variables de entorno) con permisos sobre S3, Glue y Athena. Las credenciales **no** se versionan.
- Bash o zsh (macOS, Linux o WSL2).
- Región: `us-east-2`. Bucket: `entregas-jero-eia-20261112` (valores por defecto en `variables.tf`).

## Estructura

```text
infraestructura/   principal.tf, variables.tf, salidas.tf
consultas/         SQL de la demostración
scripts/           ejecutar_consulta.sh (ejecuta una consulta en Athena y la registra)
resultados/        resultados obtenidos en Athena (inicial/ y final/)
evidencias/        apply, outputs, ejecuciones de Athena y destroy
data/              CSV de entrada suministrados (sin modificar)
resultados_esperados/  referencias suministradas
```

## Recursos creados con Terraform

| Recurso | Detalle |
|---|---|
| Bucket S3 privado | Bloqueo de acceso público, cifrado SSE-S3. Prefijos `entregas/` (datos) y `resultados-athena/` (resultados). |
| Base de datos Glue | `entregas_jero_db` |
| Tabla externa Glue | `entregas`: 5 columnas (`id_envio` string, `ciudad` string, `transportadora` string, `estado` string, `duracion_minutos` int), CSV separado por coma, `skip.header.line.count=1`, partición `fecha` string. |
| Partition projection | `projection.fecha.type=date`, formato `yyyy-MM-dd`, rango `2026-10-01,2026-10-03`, intervalo `1` `DAYS`, plantilla `s3://<bucket>/entregas/fecha=${fecha}/`. |
| Workgroup Athena | `entregas_jero_wg`, resultados en `s3://<bucket>/resultados-athena/` (configuración forzada). |

No se crean particiones individuales: Athena calcula las ubicaciones con las reglas de proyección.

## 1. Despliegue

```bash
cd infraestructura
terraform init
terraform fmt
terraform validate
terraform apply -no-color | tee ../evidencias/aplicacion_terraform.txt
terraform output -json > ../evidencias/outputs.json
cd ..
```

## 2. Carga inicial (solo días 1 y 2)

Cada archivo se sube individualmente, sin carga recursiva:

```bash
BUCKET=$(terraform -chdir=infraestructura output -raw bucket)
aws s3 cp "data/entregas/fecha=2026-10-01/entregas.csv" "s3://$BUCKET/entregas/fecha=2026-10-01/entregas.csv"
aws s3 cp "data/entregas/fecha=2026-10-02/entregas.csv" "s3://$BUCKET/entregas/fecha=2026-10-02/entregas.csv"
aws s3 ls "s3://$BUCKET/entregas/" --recursive
```

## 3. Consultas iniciales

`scripts/ejecutar_consulta.sh <etapa> <archivo_sql> <archivo_resultado> [n_sentencia]` ejecuta la sentencia en el workgroup, espera a que termine, descarga el CSV que Athena dejó en `resultados-athena/` (quitando las comillas que Athena agrega) y añade una fila a `evidencias/ejecuciones_athena.csv`.

```bash
bash scripts/ejecutar_consulta.sh inicial consultas/intentos_por_fecha_estado.sql          resultados/inicial/intentos_por_fecha_estado.csv
bash scripts/ejecutar_consulta.sh inicial consultas/porcentaje_exito_por_fecha_ciudad.sql  resultados/inicial/porcentaje_exito_por_fecha_ciudad.csv
bash scripts/ejecutar_consulta.sh inicial consultas/duracion_promedio_2026-10-02.sql       resultados/inicial/duracion_promedio_2026-10-02.csv

diff resultados/inicial/intentos_por_fecha_estado.csv          resultados_esperados/intentos_por_fecha_estado_inicial.csv
diff resultados/inicial/porcentaje_exito_por_fecha_ciudad.csv  resultados_esperados/porcentaje_exito_por_fecha_ciudad_inicial.csv
diff resultados/inicial/duracion_promedio_2026-10-02.csv       resultados_esperados/duracion_promedio_2026-10-02.csv
```

En esta etapa la tabla tiene 12 registros (6 por día). El día 3 está en el rango proyectado pero no tiene objeto en S3, así que no aporta filas.

## 4. Incorporación del día 3 (solo subir y consultar)

Sin tocar Terraform ni las propiedades de la tabla, sin crawlers, sin `MSCK REPAIR TABLE` ni `ALTER TABLE ADD PARTITION`:

```bash
aws s3 cp "data/entregas/fecha=2026-10-03/entregas.csv" "s3://$BUCKET/entregas/fecha=2026-10-03/entregas.csv"

bash scripts/ejecutar_consulta.sh final consultas/verificacion_tercer_dia.sql resultados/final/verificacion_tercer_dia.csv 1
bash scripts/ejecutar_consulta.sh final consultas/verificacion_tercer_dia.sql resultados/final/conteo_estados_tercer_dia.csv 2
bash scripts/ejecutar_consulta.sh final consultas/verificacion_tercer_dia.sql resultados/final/total_registros.csv 3

bash scripts/ejecutar_consulta.sh final consultas/intentos_por_fecha_estado.sql          resultados/final/intentos_por_fecha_estado.csv
bash scripts/ejecutar_consulta.sh final consultas/porcentaje_exito_por_fecha_ciudad.sql  resultados/final/porcentaje_exito_por_fecha_ciudad.csv

diff resultados/final/intentos_por_fecha_estado.csv          resultados_esperados/intentos_por_fecha_estado_final.csv
diff resultados/final/porcentaje_exito_por_fecha_ciudad.csv  resultados_esperados/porcentaje_exito_por_fecha_ciudad_final.csv
```

`verificacion_tercer_dia.sql` contiene tres sentencias: (1) los seis registros del 2026-10-03, (2) su conteo por estado y (3) el total de la tabla (18) con el número de fechas con datos. Las consultas agregadas ya filtraban el rango completo `2026-10-01`–`2026-10-03`, así que no se cambió su SQL.

## 5. Limpieza

Después de guardar todas las evidencias:

```bash
aws s3 rm "s3://$BUCKET" --recursive
cd infraestructura
terraform destroy -auto-approve -no-color | tee ../evidencias/eliminacion_terraform.txt
```

Se eliminan el bucket (con datos y resultados de Athena), la base de datos y la tabla de Glue y el workgroup de Athena. El estado de Terraform y las credenciales quedan fuera del repositorio (`.gitignore`).
