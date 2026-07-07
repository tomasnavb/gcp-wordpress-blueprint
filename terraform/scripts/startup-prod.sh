#!/bin/bash
# Executed on every VM boot via instance metadata
# Fetches WordPress DB credentials from Secret Manager and injects them into wp-config.php

set -e

PROJECT_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")

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

echo ">>> Fetching credentials from Secret Manager..."

DB_NAME=$(fetch_secret "wordpress-db-name")
DB_USER=$(fetch_secret "wordpress-db-user")
DB_PASSWORD=$(fetch_secret "wordpress-db-password")
DB_HOST=$(fetch_secret "wordpress-db-host")

echo ">>> Injecting credentials into wp-config.php..."

# Python handles special characters in passwords safely (sed breaks with / \ & etc.)
python3 <<PYEOF
with open('/var/www/html/wp-config.php', 'r') as f:
    content = f.read()

content = content.replace('database_name_here', '${DB_NAME}')
content = content.replace('username_here',      '${DB_USER}')
content = content.replace('password_here',      '${DB_PASSWORD}')
content = content.replace('localhost',          '${DB_HOST}')

with open('/var/www/html/wp-config.php', 'w') as f:
    f.write(content)
PYEOF

echo ">>> Restarting Apache..."
systemctl restart apache2

echo ">>> Startup complete"
