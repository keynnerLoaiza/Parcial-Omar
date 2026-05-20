variable "aws_region" {
  type        = string
  description = "Región de AWS para desplegar los recursos"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Ambiente de despliegue (dev, staging, prod)"
  default     = "production"
}

variable "project_name" {
  type        = string
  description = "Nombre del proyecto para etiquetar los recursos"
  default     = "parcial-omar"
}

variable "instance_type" {
  type        = string
  description = "Tipo de instancia EC2 para la aplicación"
  default     = "t3.micro"
}

variable "db_name" {
  type        = string
  description = "Nombre de la base de datos PostgreSQL"
  default     = "appdb"
}

variable "db_user" {
  type        = string
  description = "Usuario administrador de la base de datos"
  default     = "dbadmin"
}

variable "db_password" {
  type        = string
  description = "Contraseña para el usuario administrador de la base de datos"
  sensitive   = true
  default     = "DbSecurePassword2026!"
}

variable "github_repo_url" {
  type        = string
  description = "URL pública del repositorio de GitHub (para clonar el código en las EC2)"
  default     = "https://github.com/keynnerLoaiza/Parcial-Omar.git"
}
