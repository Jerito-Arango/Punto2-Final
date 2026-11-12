variable "region" {
  description = "Región de AWS donde se despliegan los recursos"
  type        = string
  default     = "us-east-2"
}

variable "nombre_bucket" {
  description = "Nombre globalmente único del bucket S3 del ejercicio"
  type        = string
  default     = "entregas-jero-eia-20261112"
}

variable "nombre_base_datos" {
  description = "Nombre de la base de datos de Glue Data Catalog"
  type        = string
  default     = "entregas_jero_db"
}

variable "nombre_tabla" {
  description = "Nombre de la tabla externa de Glue"
  type        = string
  default     = "entregas"
}

variable "nombre_workgroup" {
  description = "Nombre del workgroup de Athena"
  type        = string
  default     = "entregas_jero_wg"
}

variable "fecha_inicio" {
  description = "Primera fecha proyectada (yyyy-MM-dd, incluida)"
  type        = string
  default     = "2026-10-01"
}

variable "fecha_fin" {
  description = "Última fecha proyectada (yyyy-MM-dd, incluida)"
  type        = string
  default     = "2026-10-03"
}
