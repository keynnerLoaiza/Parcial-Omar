output "vpc_id" {
  description = "ID de la VPC principal"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "URL pública de la aplicación a través del balanceador de carga"
  value       = "http://${aws_lb.app_alb.dns_name}"
}

output "rds_endpoint" {
  description = "Endpoint de conexión de la base de datos RDS"
  value       = aws_db_instance.db.endpoint
}

output "rds_hostname" {
  description = "Hostname de la base de datos RDS (sin puerto)"
  value       = split(":", aws_db_instance.db.endpoint)[0]
}

output "aws_region" {
  description = "Región de AWS donde se desplegó la infraestructura"
  value       = var.aws_region
}
