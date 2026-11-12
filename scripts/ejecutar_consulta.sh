#!/usr/bin/env bash
# Ejecuta UNA sentencia de un archivo .sql en Athena, descarga el CSV de resultado
# y registra la ejecución en evidencias/ejecuciones_athena.csv
#
# Uso (desde la raíz del repo):
#   bash scripts/ejecutar_consulta.sh <etapa> <archivo_sql> <archivo_resultado> [n_sentencia]
# Ej.:
#   bash scripts/ejecutar_consulta.sh inicial consultas/intentos_por_fecha_estado.sql resultados/inicial/intentos_por_fecha_estado.csv
#   bash scripts/ejecutar_consulta.sh final consultas/verificacion_tercer_dia.sql resultados/final/verificacion_tercer_dia.csv 1
set -euo pipefail

ETAPA="$1"; SQL_FILE="$2"; OUT_FILE="$3"; N="${4:-1}"
WG="$(terraform -chdir=infraestructura output -raw workgroup)"
DB="$(terraform -chdir=infraestructura output -raw base_datos)"
REGION="$(terraform -chdir=infraestructura output -raw region)"
REGISTRO="evidencias/ejecuciones_athena.csv"

# Extrae la sentencia N (separadas por ';'), quitando comentarios '--'
SQL="$(sed 's/--.*$//' "$SQL_FILE" | awk -v n="$N" 'BEGIN{RS=";"} { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, ""); if (length($0)>0) { i++; if (i==n) { print; exit } } }')"
if [ -z "$SQL" ]; then echo "No se encontró la sentencia $N en $SQL_FILE" >&2; exit 1; fi
echo ">> Ejecutando ($ETAPA) $SQL_FILE [sentencia $N] en workgroup $WG"

QID="$(aws athena start-query-execution --region "$REGION" --work-group "$WG" \
        --query-execution-context Database="$DB" --query-string "$SQL" \
        --query QueryExecutionId --output text)"
echo "   id_ejecucion: $QID"

while true; do
  STATE="$(aws athena get-query-execution --region "$REGION" --query-execution-id "$QID" \
           --query QueryExecution.Status.State --output text)"
  case "$STATE" in
    SUCCEEDED) break ;;
    FAILED|CANCELLED)
      aws athena get-query-execution --region "$REGION" --query-execution-id "$QID" \
        --query QueryExecution.Status.StateChangeReason --output text >&2
      exit 1 ;;
    *) sleep 1 ;;
  esac
done

S3_OUT="$(aws athena get-query-execution --region "$REGION" --query-execution-id "$QID" \
          --query QueryExecution.ResultConfiguration.OutputLocation --output text)"
mkdir -p "$(dirname "$OUT_FILE")"
# Athena entrecomilla todos los valores; los datos no tienen comas, así que se quitan las comillas
aws s3 cp --region "$REGION" "$S3_OUT" - | tr -d '"' > "$OUT_FILE"
echo "   resultado: $S3_OUT -> $OUT_FILE"
cat "$OUT_FILE"

[ -f "$REGISTRO" ] || echo "etapa,archivo_sql,id_ejecucion,archivo_resultado" > "$REGISTRO"
echo "$ETAPA,$SQL_FILE,$QID,$OUT_FILE" >> "$REGISTRO"
