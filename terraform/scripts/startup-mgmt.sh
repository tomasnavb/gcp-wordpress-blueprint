#!/bin/bash
set -e

PROJECT_ID=$(curl -s \
  "http://metadata.google.internal/computeMetadata/v1/project/project-id" \
  -H "Metadata-Flavor: Google")

fetch_secret() {
  local secret_name=$1
  local max_attempts=10
  local attempt=1
  local value

  while [ $attempt -le $max_attempts ]; do
    value=$(gcloud secrets versions access latest --secret="$secret_name" --project="$PROJECT_ID" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$value" ]; then
      echo "$value"
      return 0
    fi
    echo ">>> Attempt $attempt/$max_attempts: waiting for secret $secret_name..." >&2
    sleep 10
    attempt=$((attempt + 1))
  done

  echo ">>> ERROR: Failed to fetch secret $secret_name after $max_attempts attempts." >&2
  return 1
}

echo ">>> Installing Cloud SQL Auth Proxy..."

INSTANCE_CONNECTION_NAME=$(fetch_secret "wordpress-db-instance-connection")

wget https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.1.0/cloud-sql-proxy.linux.amd64 \
  -O /usr/local/bin/cloud-sql-proxy
chmod +x /usr/local/bin/cloud-sql-proxy

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
