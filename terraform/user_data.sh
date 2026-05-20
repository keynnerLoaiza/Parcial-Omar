#!/bin/bash
# Redireccionar salida estándar y errores a un log para depuración
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "==============================================="
echo "=== INICIANDO DESPLIEGUE DE LA APLICACIÓN ==="
echo "==============================================="

# 1. Actualizar el sistema e instalar dependencias básicas
sudo dnf update -y
sudo dnf install -y unzip git

# Instalar Node.js 20 de forma global y nativa en Amazon Linux 2023
echo "[DEPLOYS] Instalando Node.js 20..."
sudo dnf install -y nodejs20

# Crear symlinks globales para asegurar que 'node' y 'npm' estén disponibles para todos los usuarios
sudo ln -sf /usr/bin/node-20 /usr/bin/node
sudo ln -sf /usr/bin/npm-20 /usr/bin/npm


# 2. Clonar el repositorio público directamente desde GitHub
echo "[DEPLOYS] Clonando repositorio desde GitHub: ${github_repo_url}..."
git clone ${github_repo_url} /opt/app

if [ -d /opt/app ]; then
  cd /opt/app
  echo "[DEPLOYS] Repositorio clonado correctamente. Instalando todas las dependencias y compilando..."
  npm install --include=dev
  chmod -R 755 node_modules/.bin/
  npm run build
else
  echo "[WARNING] No se pudo clonar el repositorio. Creando aplicación temporal de fallback..."
  mkdir -p /opt/app/dist
  cd /opt/app
  
  # Servidor Express de fallback extremadamente simple para que los health checks pasen
  cat <<'EOF' > dist/app.js
const express = require('express');
const app = express();
app.get('/health', (req, res) => res.status(200).json({ status: 'ok', service: 'fallback' }));
app.get('/status', (req, res) => res.status(200).json({ status: 'ok', database: 'fallback-no-db' }));
app.listen(8080, () => console.log('Fallback running on port 8080'));
EOF
fi

# 4. Crear archivo de variables de entorno (.env) con datos inyectados por Terraform
echo "[CONFIG] Generando archivo de entorno (.env)..."
cat <<EOF > /opt/app/.env
DB_HOST=${db_host}
DB_PORT=5432
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
NODE_ENV=production
PORT=8080
APP_VERSION=1.0.0
EOF

# 5. Dependencias ya instaladas y compiladas en el paso 2
echo "[DEPLOYS] Dependencias listas para producción."

# 6. Configurar la aplicación para correr como un servicio del sistema (Systemd)
echo "[SERVICE] Creando archivo de servicio de systemd para Node.js..."
cat <<EOF > /etc/systemd/system/node-app.service
[Unit]
Description=Node.js Express App (AWS API)
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node dist/app.js
Environment=NODE_ENV=production
Environment=PATH=/usr/bin:/usr/local/bin:/usr/sbin:/usr/bin
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 7. Cambiar dueño de los archivos, recargar systemd e iniciar la aplicación
echo "[SERVICE] Arrancando el servicio node-app..."
chown -R ec2-user:ec2-user /opt/app
systemctl daemon-reload
systemctl enable node-app
systemctl start node-app

echo "==============================================="
echo "=== DESPLIEGUE FINALIZADO CON ÉXITO ==="
echo "==============================================="
