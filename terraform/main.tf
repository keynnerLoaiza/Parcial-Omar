# ==============================================================================
# Terraform Configuración Principal - Examen Final AWS, Terraform y CI/CD
# ==============================================================================

# Data source para obtener las zonas de disponibilidad en la región actual
data "aws_availability_zones" "available" {
  state = "available"
}

# Generar un ID aleatorio para asegurar nombres de bucket S3 y DB únicos globalmente
resource "random_id" "suffix" {
  byte_length = 4
}

# ==============================================================================
# 1. Red (VPC, Subnets, Routing, Gateways)
# ==============================================================================

# VPC Principal
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway para tráfico público
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# 2 Subredes Públicas (para el Balanceador de Carga - ALB)
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-2"
    Environment = var.environment
  }
}

# 2 Subredes Privadas (para Servidores de Aplicación - EC2)
resource "aws_subnet" "private_app_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.project_name}-private-app-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_app_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.project_name}-private-app-2"
    Environment = var.environment
  }
}

# 2 Subredes Privadas (para Base de Datos - RDS)
resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.project_name}-private-db-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.project_name}-private-db-2"
    Environment = var.environment
  }
}

# Elastic IP para el NAT Gateway
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
  }
}

# NAT Gateway para permitir salida a internet a las instancias privadas
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name        = "${var.project_name}-nat-gw"
    Environment = var.environment
  }
}

# Tablas de Ruteo Públicas y Privadas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

# Asociaciones de Tabla de Ruteo Pública
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Asociaciones de Tabla de Ruteo Privada (App)
resource "aws_route_table_association" "private_app_1" {
  subnet_id      = aws_subnet.private_app_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_app_2" {
  subnet_id      = aws_subnet.private_app_2.id
  route_table_id = aws_route_table.private.id
}

# Asociaciones de Tabla de Ruteo Privada (DB) - Sin salida a Internet directa
resource "aws_route_table_association" "private_db_1" {
  subnet_id      = aws_subnet.private_db_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db_2" {
  subnet_id      = aws_subnet.private_db_2.id
  route_table_id = aws_route_table.private.id
}

# ==============================================================================
# 2. Controles de Acceso (Security Groups)
# ==============================================================================

# Security Group del Balanceador de Carga (ALB)
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Permitir trafico HTTP entrante desde internet hacia el ALB"
  vpc_id      = aws_vpc.main.id

  # Inbound HTTP (Puerto 80)
  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound total
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
  }
}

# Security Group de las Instancias de Aplicación (EC2)
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Permitir trafico unicamente desde el ALB hacia las instancias EC2"
  vpc_id      = aws_vpc.main.id

  # Inbound desde el ALB únicamente (Puerto 8080)
  ingress {
    description     = "HTTP desde el ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Inbound SSH (opcional/desactivado por defecto. Se recomienda usar SSM Session Manager sin abrir puerto 22)
  # ingress {
  #   description = "SSH desde cualquier origen"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # Outbound total (para descargar paquetes NPM y comunicarse con RDS)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-app-sg"
    Environment = var.environment
  }
}

# Security Group de la Base de Datos (RDS)
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Restringir acceso a la DB unicamente desde las instancias privadas de aplicacion"
  vpc_id      = aws_vpc.main.id

  # Inbound PostgreSQL (Puerto 5432) únicamente desde el Security Group de la App
  ingress {
    description     = "PostgreSQL desde la infraestructura de la App"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  # Outbound total (para réplica y comunicaciones internas)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-db-sg"
    Environment = var.environment
  }
}

# ==============================================================================
# 3. Almacenamiento (Removido S3 para compatibilidad con AWS Academy SCP)
# ==============================================================================
# Nota: AWS Academy bloquea la API s3:GetBucketObjectLockConfiguration de forma
# explícita, haciendo que la creación de buckets de S3 en Terraform falle.
# Usamos un esquema GitOps directo clonando el repositorio público de GitHub en EC2.

# ==============================================================================
# 4. Base de Datos (RDS PostgreSQL de una sola AZ por límites de AWS Academy)
# ==============================================================================

# Grupo de Subredes para RDS
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_db_1.id, aws_subnet.private_db_2.id]

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# Instancia de base de datos PostgreSQL Single-AZ (Multi-AZ está explícitamente bloqueado en el Learner Lab)
resource "aws_db_instance" "db" {
  identifier             = "${var.project_name}-db-${random_id.suffix.hex}"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  engine                 = "postgres"
  engine_version         = "16.9"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  
  # Deshabilitado para cumplir con la política de control de servicios (SCP) de AWS Academy
  multi_az               = false
  
  skip_final_snapshot    = true
  publicly_accessible    = false # Completamente aislada de internet
  deletion_protection    = false

  tags = {
    Name        = "${var.project_name}-rds-db"
    Environment = var.environment
  }
}

# ==============================================================================
# 5. Cómputo y Balanceo de Carga (ALB, Target Group, Launch Template, ASG)
# ==============================================================================

# Obtener la AMI más reciente de Amazon Linux 2023
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-202*-x86_64"]
  }
}

# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# Target Group para las instancias de la App
resource "aws_lb_target_group" "app_tg" {
  name        = "${var.project_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  # Configuración del Health Check (Chequeo de salud hacia /health en el puerto 8080)
  health_check {
    path                = "/health"
    port                = "8080"
    protocol            = "HTTP"
    interval            = 20
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-target-group"
    Environment = var.environment
  }
}

# Listener del ALB redireccionando el puerto 80 al Target Group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Launch Template para el Auto Scaling Group
resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.project_name}-launch-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  # Rol de AWS Academy pre-configurado para permitir las comunicaciones internas
  iam_instance_profile {
    name = "LabInstanceProfile"
  }

  # Configuración de Red
  network_interfaces {
    associate_public_ip_address = false # Totalmente privada, no expuesta a Internet directa
    security_groups             = [aws_security_group.app_sg.id]
  }

  # Script de Inicialización de la Instancia (User Data) con inyección de variables
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    github_repo_url = var.github_repo_url
    db_host        = split(":", aws_db_instance.db.endpoint)[0]
    db_name        = var.db_name
    db_user        = var.db_user
    db_password    = var.db_password
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-app-node"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group (ASG) para Alta Disponibilidad y Resiliencia ante fallos
resource "aws_autoscaling_group" "app_asg" {
  name_prefix         = "${var.project_name}-asg-"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  vpc_zone_identifier = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
  target_group_arns   = [aws_lb_target_group.app_tg.arn]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  # Esperar a que las instancias pasen el health check del ALB
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Forzar actualización inmutable de instancias si cambia la plantilla
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-asg"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
