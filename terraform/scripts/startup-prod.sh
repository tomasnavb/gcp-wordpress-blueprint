#!/bin/bash
# Executed on every VM boot via instance metadata
# Fetches WordPress DB credentials from Secret Manager and injects them into wp-config.php

set -e

PROJECT_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")

echo ">>> Fetching credentials from Secret Manager..."

DB_NAME=$(gcloud secrets versions access latest --secret="wordpress-db-name" --project="$PROJECT_ID" 2>/dev/null)
DB_USER=$(gcloud secrets versions access latest --secret="wordpress-db-user" --project="$PROJECT_ID" 2>/dev/null)
DB_PASSWORD=$(gcloud secrets versions access latest --secret="wordpress-db-password" --project="$PROJECT_ID" 2>/dev/null)
DB_HOST=$(gcloud secrets versions access latest --secret="wordpress-db-host" --project="$PROJECT_ID" 2>/dev/null)

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
