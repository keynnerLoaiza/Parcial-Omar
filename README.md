# Examen Final AWS: Diseño, Automatización, Despliegue y Pruebas

Este repositorio contiene la solución completa para el examen final de Infraestructura Tecnológica en AWS. El proyecto implementa un servicio REST API funcional desarrollado en Node.js + Express + TypeScript, con infraestructura automatizada en AWS mediante Terraform, un pipeline completo de CI/CD utilizando GitHub Actions, pruebas automatizadas locales, pruebas de carga con k6 y documentación detallada.

---

## 1. Arquitectura Tecnológica en AWS

La infraestructura diseñada implementa las mejores prácticas del marco de buena arquitectura de AWS (*AWS Well-Architected Framework*), enfocándose en **Seguridad**, **Alta Disponibilidad** y **Resiliencia**.

```text
Simplificado
                                  [ TRÁFICO DE USUARIOS ]
                                             │
                                             ▼
                                  [ Internet Gateway ]
                                             │
                                             ▼
                        [ Application Load Balancer (ALB) - Public ]
                               (Subredes Públicas Multi-AZ)
                                             │
                       ┌─────────────────────┴─────────────────────┐
                       │ (Port 8080)                               │ (Port 8080)
                       ▼                                           ▼
          [ Instancia EC2 App - A ]                    [ Instancia EC2 App - B ]
        (Subred Privada 1 - us-east-1a)              (Subred Privada 2 - us-east-1b)
                       │                                           │
                       └─────────────────────┬─────────────────────┘
                                             │ (Port 5432)
                                             ▼
                                 [ RDS PostgreSQL - Primary ]
                               (Subred Privada DB 1 - us-east-1a)
                                             │
                                             │ (Replicación Síncrona)
                                             ▼
                                 [ RDS PostgreSQL - Standby ]
                               (Subred Privada DB 2 - us-east-1b)
```

### Decisiones de Diseño de Arquitectura:
1. **Segmentación de Red (VPC)**:
   - **VPC** con direccionamiento `10.0.0.0/16`.
   - **2 Subredes Públicas** (`10.0.1.0/24` y `10.0.2.0/24`) que alojan el **Application Load Balancer (ALB)**. Son las únicas subredes con acceso directo desde el exterior.
   - **2 Subredes Privadas para Cómputo** (`10.0.3.0/24` y `10.0.4.0/24`) que alojan las instancias de aplicación. No tienen IP pública asignada.
   - **2 Subredes Privadas para DB** (`10.0.5.0/24` y `10.0.6.0/24`) completamente aisladas del exterior.
2. **Alta Disponibilidad y Tolerancia a Fallos**:
   - **Cómputo**: Las instancias EC2 se despliegan de forma redundante mediante un **Auto Scaling Group (ASG)** con una capacidad deseada de 2 instancias distribuidas en dos zonas de disponibilidad (AZ) diferentes (`us-east-1a` y `us-east-1b`). Si una zona o una instancia falla, el balanceador redirige el tráfico y el ASG auto-recupera (*self-healing*) la instancia.
   - **Base de Datos**: Se utiliza un cluster **RDS PostgreSQL con Multi-AZ activado (`multi_az = true`)**. AWS aprovisiona y mantiene automáticamente una réplica síncrona en otra zona de disponibilidad. En caso de falla en el nodo principal, RDS realiza una conmutación por error (*failover*) automática sin intervención humana.
3. **Controles de Acceso (Seguridad)**:
   - **Security Group del ALB (`alb_sg`)**: Solo permite entrada por el puerto HTTP `80` desde cualquier origen (`0.0.0.0/0`).
   - **Security Group de la App (`app_sg`)**: Solo permite tráfico TCP en el puerto `8080` (puerto de Express) proveniente del grupo de seguridad del ALB. **Nadie de internet puede comunicarse directamente con las instancias EC2**.
   - **Security Group de la DB (`db_sg`)**: Solo permite tráfico en el puerto PostgreSQL `5432` proveniente del grupo de seguridad de la App.
4. **Almacenamiento Segurizado**:
   - Se crea un bucket **Amazon S3** con bloqueo de acceso público y cifrado por defecto para almacenar los artefactos de compilación (`app.zip`) de forma segura.

---

## 2. Estructura de Archivos del Proyecto

El código está organizado de manera modular e intuitiva siguiendo estándares profesionales de desarrollo de software:

```text
Parcial-Omar/
├── .github/
│   └── workflows/
│       └── ci-cd.yml             # Pipeline de GitHub Actions (Lint, Test, Build, Upload S3)
├── src/                          # Código fuente de la API REST
│   ├── app.ts                    # Inicialización del servidor Express y Base de Datos
│   ├── db/
│   │   └── connection.ts         # Pool de conexión a la base de datos PostgreSQL
│   ├── routes/
│   │   ├── health.ts             # Rutas de salud y métricas (/health, /status, /api/test)
│   │   └── products.ts           # Rutas del CRUD de productos (/api/products)
├── tests/                        # Pruebas automatizadas (Jest + Supertest)
│   ├── __mocks__/
│   │   └── db.ts                 # Mock de la base de datos PostgreSQL para pruebas unitarias
│   ├── health.test.ts            # Pruebas sobre endpoints de salud
│   └── products.test.ts          # Pruebas sobre CRUD de productos
├── terraform/                    # Infraestructura como Código (IaC)
│   ├── provider.tf               # Proveedores requeridos y configuración de AWS
│   ├── variables.tf              # Declaración de variables del entorno
│   ├── main.tf                   # Definición completa de recursos en AWS (VPC, ALB, ASG, RDS, S3)
│   ├── outputs.tf                # Salidas del despliegue (DNS del ALB, RDS, S3)
│   ├── terraform.tfvars.example  # Ejemplo de variables sensibles
│   └── user_data.sh              # Script Bash para inicializar y auto-desplegar en las EC2
├── performance/                  # Pruebas de Desempeño
│   └── k6-test.js                # Script de simulación de carga con k6
├── .eslintcr.json                # Configuración de ESLint para TypeScript
├── tsconfig.json                 # Configuración del compilador de TypeScript
├── package.json                  # Definición de scripts y dependencias
└── README.md                     # Este archivo (Guía y documentación)
```

---

## 3. Pruebas y Desarrollo Local

Antes de desplegar en AWS, puedes ejecutar y validar la aplicación de forma local:

### 3.1 Instalar Dependencias
Asegúrate de tener Node.js v20 instalado y ejecuta:
```bash
npm install
```

### 3.2 Ejecutar Linter
Valida que el código cumpla con los estándares de estilo y sintaxis de TypeScript:
```bash
npm run lint
```

### 3.3 Ejecutar Pruebas Unitarias e Integración (Con Reporte de Cobertura)
Ejecuta las pruebas mockeadas. No necesitas tener PostgreSQL instalado localmente para que pasen con éxito:
```bash
npm run test
```

### 3.3 Ejecutar en Modo de Desarrollo
Si deseas correr la aplicación localmente:
```bash
npm run dev
```

---

## 4. Despliegue de la Infraestructura en AWS con Terraform

Sigue estos pasos para desplegar toda la infraestructura automatizada:

### 4.1 Requisitos
1. Tener **Terraform** instalado.
2. Iniciar tu laboratorio en **AWS Academy** y copiar las credenciales de la consola (haciendo clic en *AWS Details* -> *AWS CLI Credentials*).
3. Configurar tus variables de entorno locales en una terminal o archivo de configuración de AWS (normalmente `~/.aws/credentials` en Linux/Mac o `%USERPROFILE%\.aws\credentials` en Windows):
   ```ini
   [default]
   aws_access_key_id = ASIA...
   aws_secret_access_key = ...
   aws_session_token = IQoJb3JpZ2luX2Vj...
   ```

### 4.2 Preparar Variables
Entra a la carpeta de terraform, copia el archivo de variables de ejemplo y llénalo con los datos deseados:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```
*(Modifica las contraseñas de la DB en `terraform.tfvars` si lo deseas)*.

### 4.3 Comandos de Despliegue
1. **Inicializar Terraform** (descarga plugins del proveedor de AWS):
   ```bash
   terraform init
   ```
2. **Validar Configuración**:
   ```bash
   terraform validate
   ```
3. **Planificar Despliegue** (simula y detalla qué recursos se crearán):
   ```bash
   terraform plan
   ```
4. **Aplicar Despliegue** (crea los recursos en AWS, tarda aproximadamente entre 6 y 10 minutos debido a la DB en Multi-AZ):
   ```bash
   terraform apply -auto-approve
   ```

Al finalizar exitosamente el comando, Terraform expondrá las salidas (*outputs*):
- `alb_dns_name`: La URL pública para acceder a tu servidor REST API (ejemplo: `http://parcial-omar-alb-12345678.us-east-1.elb.amazonaws.com`).
- `rds_endpoint`: El endpoint interno de la base de datos.
- `s3_bucket_name`: El nombre del bucket S3 para empaquetar el código.

---

## 5. Configuración del Pipeline de CI/CD (GitHub Actions)

El archivo `.github/workflows/ci-cd.yml` automatiza todo el ciclo de entrega e integra un flujo inmutable.

### 5.1 Flujo del Pipeline:
1. **Fase de Integración Continua (CI)**:
   - Se activa ante cada *push* o *pull request* en la rama `main`.
   - Clona el código, instala dependencias, ejecuta el linter, corre los tests unitarios de Jest y valida la compilación TypeScript.
2. **Fase de Despliegue Continuo (CD)**:
   - Se ejecuta únicamente en la rama `main` tras el éxito de los tests.
   - Genera un archivo empaquetado `app.zip` (que incluye la carpeta `dist` compilada y los archivos `package*.json`).
   - Se conecta a AWS y sube el archivo `app.zip` al bucket S3 de Terraform.
   - Dispara una actualización en Auto Scaling (`aws autoscaling start-instance-refresh`). Las instancias EC2 se terminan de forma escalonada y se levantan nuevas instancias que descargan automáticamente el nuevo zip desde S3 y lo ponen a correr en segundos. **Cero tiempo de inactividad**.

### 5.2 Secretos de GitHub Requeridos:
Para que el pipeline funcione, debes agregar los siguientes Secretos en tu repositorio de GitHub (`Settings -> Secrets and variables -> Actions -> New repository secret`):
- `AWS_ACCESS_KEY_ID`: ID de tu clave de acceso temporal de AWS Academy.
- `AWS_SECRET_ACCESS_KEY`: Clave de acceso secreta temporal de AWS Academy.
- `AWS_SESSION_TOKEN`: Token de sesión de AWS Academy (obligatorio para cuentas de estudiantes).
- `AWS_S3_BUCKET`: Nombre de tu bucket S3 obtenido en la salida de Terraform (`s3_bucket_name`).
- `AWS_ASG_NAME`: Nombre de tu Auto Scaling Group en AWS (obtenible en la consola o en Terraform).

---

## 6. Pruebas de Desempeño (Carga) con k6

El examen requiere medir la resiliencia del balanceador de carga y la saturación del sistema utilizando una herramienta como **k6**.

### 6.1 Ejecución Local de k6
Si no tienes k6 instalado, puedes descargarlo de su web oficial o instalarlo mediante administradores de paquetes (`choco install k6` en Windows, `brew install k6` en Mac).

1. Abre una terminal.
2. Ejecuta el script de carga configurando la URL de tu balanceador (reemplaza por tu salida de Terraform):
   ```bash
   k6 run performance/k6-test.js --env TARGET_URL=http://<ALB-DNS-NAME>
   ```

### 6.2 Qué mide esta prueba:
El script `performance/k6-test.js` realiza las siguientes simulaciones bajo carga:
- **Rampa de Carga**: Sube progresivamente de 0 a 50 usuarios virtuales en 30s, los mantiene por 1m40s y baja a 0 en 30s.
- **Flujo Realista**: Cada usuario virtual (VU) realiza de forma concurrente:
  - Lecturas en `/health` y `/api/test`.
  - Peticiones GET a `/api/products`.
  - Creaciones de productos reales en PostgreSQL (`POST /api/products`).
  - Consultas específicas del producto creado (`GET /api/products/:id`).
  - Eliminaciones de los productos (`DELETE /api/products/:id`).
  - Verificación del estado e integridad de la base de datos en `/status` (`SELECT 1`).
- **Límites de Éxito (*Thresholds*)**:
  - Tasa de errores inferior al 1% (`http_req_failed: ['rate<0.01']`).
  - 95% de los tiempos de respuesta inferiores a 500ms (`http_req_duration: ['p(95)<500']`).

### 6.3 Monitoreo en AWS Console:
Durante o después de la prueba de k6, abre tu consola de AWS y dirígete a:
1. **EC2 -> Target Groups**: Observa cómo disminuyen los tiempos de respuesta o cómo distribuye las peticiones.
2. **CloudWatch -> Metrics**: Busca las métricas del Balanceador de Carga (ALB):
   - `RequestCount`: Total de peticiones atendidas por el ALB.
   - `ActiveConnectionCount`: Conexiones activas simultáneas.
   - `TargetResponseTime`: Tiempo que tardaron las instancias de Express en responderle al ALB.
3. **RDS -> Metrics**: Monitorea el consumo de CPU (`CPUUtilization`) y las conexiones activas a la base de datos (`DatabaseConnections`) en tu instancia principal.

---

## 7. Guía Paso a Paso para la Sustentación del Video (Máxima Nota)

El examen penaliza fuertemente a grupos donde algún integrante no participe o no demuestre el uso de su propia consola de AWS Academy. Les sugerimos dividir la sustentación de la siguiente forma (tiempo máximo total: 10 minutos):

### Integrante 1: Explicación de la Arquitectura y Redes (Minutos 0 a 3)
* **Acción**: Muestra el diagrama de infraestructura (con iconos oficiales AWS 2026).
* **Guion técnico**:
  - Explica la segmentación de red: por qué la VPC tiene un CIDR `/16`, qué rango tienen las subredes y por qué hay subredes públicas y privadas.
  - Justifica el uso de un balanceador de carga público (ALB) y el Auto Scaling Group para alta disponibilidad.
  - Explica los grupos de seguridad y por qué la base de datos está totalmente aislada de internet y solo acepta tráfico de las instancias en la subred privada.
  - Explica por qué se configuró RDS en Multi-AZ (réplica síncrona automática) para prevenir fallos físicos de un centro de datos.

### Integrante 2: Infraestructura como Código con Terraform (Minutos 3 a 5)
* **Acción**: Muestra su pantalla con el código Terraform en VS Code. Ejecuta o muestra la ejecución de los comandos en tiempo real.
* **Guion técnico**:
  - Explica brevemente los archivos: `provider.tf`, `variables.tf`, `main.tf`, `outputs.tf` y `user_data.sh`.
  - Muestra cómo inyectan las credenciales de la DB de RDS a las instancias EC2 mediante la plantilla de `user_data.sh`.
  - Explica el uso del perfil de instancia `LabInstanceProfile` especial de AWS Academy.
  - Muestra el resultado final de `terraform apply` o las salidas de `terraform output` demostrando que toda la infraestructura se creó de forma 100% automatizada.

### Integrante 3: Servicio REST Desplegado y Monitoreo de Salud (Minutos 5 a 7)
* **Acción**: Abre un navegador, Postman o curl para consultar los endpoints de la API real montada en AWS.
* **Guion técnico**:
  - Realiza una consulta a `http://<ALB-DNS-NAME>/health` demostrando respuesta HTTP `200` y estado `ok`.
  - Realiza una consulta a `http://<ALB-DNS-NAME>/status` (¡Esta es la prueba estrella!). Muestra cómo la API se conecta exitosamente a RDS PostgreSQL, indicando `database: "connected"` y exponiendo la latencia de respuesta de la DB.
  - Realiza peticiones POST y GET a `/api/products` demostrando el correcto guardado y lectura de datos.

### Integrante 4: Pipeline de CI/CD y Pruebas Unitarias (Minutos 7 a 9)
* **Acción**: Abre GitHub o GitLab y muestra la pestaña "Actions" (o Pipelines). Realiza un pequeño cambio cosmético en el código, haz commit, push y muestra cómo se dispara el pipeline de forma automática.
* **Guion técnico**:
  - Explica las etapas del pipeline: instalación, ejecución del linter, pruebas de Jest (que deben pasar al 100%) y compilación de TypeScript.
  - Explica el proceso de despliegue inmutable: cómo se sube el `app.zip` a S3 y cómo la llamada de Auto Scaling realiza el refresco de instancias de forma segura sin caída de servicio.
  - Muestra la ejecución del pipeline con el indicador verde de éxito (`Success`).

### Integrante 5: Pruebas de Desempeño con k6 y Monitoreo en CloudWatch (Minutos 9 a 10)
* **Acción**: Muestra la terminal ejecutando el comando de k6 en tiempo real. Al finalizar la prueba, comparte la pantalla de la Consola de AWS (CloudWatch) mostrando las gráficas de tráfico.
* **Guion técnico**:
  - Explica la configuración del script de k6: rampa de usuarios virtuales de hasta 50 concurrencias.
  - Muestra los resultados en la terminal: 0% de solicitudes fallidas y tiempos de respuesta promedio muy por debajo de los 100ms.
  - Muestra las gráficas de CloudWatch donde se ve el pico de peticiones (`RequestCount`) en el ALB y cómo la CPU de las instancias EC2 se mantuvo estable gracias a la distribución del balanceador.
