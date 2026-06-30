#!/bin/bash
# startup-script.sh
# Executed on every VM boot via instance metadata
# Injects WordPress DB credentials from Secret Manager

set -e

echo ">>> Fetching credentials from Secret Manager..."

PROJECT_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")

DB_NAME=$(gcloud secrets versions access latest \
  --secret="wordpress-db-name" \
  --project="$PROJECT_ID")

DB_USER=$(gcloud secrets versions access latest \
  --secret="wordpress-db-user" \
  --project="$PROJECT_ID")

DB_PASSWORD=$(gcloud secrets versions access latest \
  --secret="wordpress-db-password" \
  --project="$PROJECT_ID")

DB_HOST=$(gcloud secrets versions access latest \
  --secret="wordpress-db-host" \
  --project="$PROJECT_ID")

echo ">>> Injecting credentials into wp-config.php..."

sed -i "s/database_name_here/$DB_NAME/" /var/www/html/wp-config.php
sed -i "s/username_here/$DB_USER/" /var/www/html/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" /var/www/html/wp-config.php
sed -i "s/localhost/$DB_HOST/" /var/www/html/wp-config.php

echo ">>> Restarting Apache..."
systemctl restart apache2

echo ">>> Startup complete"