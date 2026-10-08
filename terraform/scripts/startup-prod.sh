#!/bin/bash
# Executed on every VM boot via instance metadata
# Fetches WordPress DB credentials from Secret Manager and injects them into wp-config.php,
# then mounts the uploads bucket at wp-content/uploads with Cloud Storage FUSE.
#
# The last step creates /run/wordpress-configured. health.php answers 200 only when that file
# exists, so an instance where this script failed gets no traffic and is replaced by auto-healing.

set -e

READY_MARKER="/run/wordpress-configured"
rm -f "$READY_MARKER"

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

echo ">>> Mounting the uploads bucket..."
# The bucket name comes from the instance metadata (key uploads-bucket), set by Terraform, so the
# image and this script work in any project. The mount is gone after a reboot and this script
# runs again on every boot, so it is mounted here and not in /etc/fstab.
#   --implicit-dirs  shows folders that exist only as a prefix of object names, for example
#                    uploads copied straight into the bucket with gcloud when restoring a backup.
#   -o allow_other   this script runs as root; Apache, as www-data, must be able to use the mount.
#   --uid / --gid    files and folders appear owned by www-data, so WordPress can write uploads.
# If the mount fails the script stops before the readiness marker, and the instance is replaced.
UPLOADS_BUCKET=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/uploads-bucket" -H "Metadata-Flavor: Google")
UPLOADS_DIR="/var/www/html/wp-content/uploads"

if ! mountpoint -q "$UPLOADS_DIR"; then
  gcsfuse \
    --implicit-dirs \
    -o allow_other \
    --uid "$(id -u www-data)" \
    --gid "$(id -g www-data)" \
    --file-mode 644 \
    --dir-mode 755 \
    "$UPLOADS_BUCKET" "$UPLOADS_DIR"
fi
mountpoint -q "$UPLOADS_DIR"

echo ">>> Restarting Apache..."
systemctl restart apache2

touch "$READY_MARKER"
echo ">>> Startup complete"
