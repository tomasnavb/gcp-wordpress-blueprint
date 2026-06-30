#!/bin/bash
set -e

echo ">>> Installing Cloud SQL Auth Proxy..."

# Obtener project_id y connection name desde Secret Manager
PROJECT_ID=$(curl -s \
  "http://metadata.google.internal/computeMetadata/v1/project/project-id" \
  -H "Metadata-Flavor: Google")

INSTANCE_CONNECTION_NAME=$(gcloud secrets versions access latest \
  --secret="cloudsql-connection-name" \
  --project="$PROJECT_ID")

# Instalar el proxy
wget https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.1.0/cloud-sql-proxy.linux.amd64 \
  -O /usr/local/bin/cloud-sql-proxy
chmod +x /usr/local/bin/cloud-sql-proxy

# Crear servicio systemd
cat <<EOF > /etc/systemd/system/cloud-sql-proxy.service
[Unit]
Description=Cloud SQL Auth Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/cloud-sql-proxy \
  --address 127.0.0.1 \
  --port 3306 \
  $INSTANCE_CONNECTION_NAME
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloud-sql-proxy
systemctl start cloud-sql-proxy

echo ">>> Cloud SQL Auth Proxy running"