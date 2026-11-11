#!/bin/bash
# Executed on every VM boot via instance metadata
# Fetches WordPress DB credentials from Secret Manager and injects them into wp-config.php,
# then mounts the uploads bucket at wp-content/uploads with Cloud Storage FUSE.
#
# Every name it needs (secrets, bucket, folder) comes from the instance metadata, set by Terraform
# from the same values it uses to create those resources (terraform/compute.tf): nothing is hardcoded,
# so the image and this script work in any project and environment.
#
# The last step creates /run/wordpress-configured. health.php answers 200 only when that file
# exists, so an instance where this script failed gets no traffic and is replaced by auto-healing.

set -e

READY_MARKER="/run/wordpress-configured"
rm -f "$READY_MARKER"

PROJECT_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")

# Value of an instance metadata key. Fails if the key is missing or empty, which stops the script.
metadata() {
  local value
  value=$(curl -sf "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1" -H "Metadata-Flavor: Google")
  if [ -z "$value" ]; then
    echo ">>> ERROR: instance metadata key $1 is missing or empty." >&2
    return 1
  fi
  echo "$value"
}

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

# Secret names first, each in its own assignment: set -e stops the script if a key is missing.
SECRET_DB_NAME=$(metadata secret-db-name)
SECRET_DB_USER=$(metadata secret-db-user)
SECRET_DB_PASSWORD=$(metadata secret-db-password)
SECRET_DB_HOST=$(metadata secret-db-host)

DB_NAME=$(fetch_secret "$SECRET_DB_NAME")
DB_USER=$(fetch_secret "$SECRET_DB_USER")
DB_PASSWORD=$(fetch_secret "$SECRET_DB_PASSWORD")
DB_HOST=$(fetch_secret "$SECRET_DB_HOST")

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

echo ">>> Setting the site address in wp-config.php..."
# WP_HOME and WP_SITEURL fix the address WordPress builds its links and redirects with, the password
# reset link among them. Without them WordPress takes it from the database, and before the
# installation from the Host header of the request, which the client writes (PortSwigger, HTTP Host
# header attacks). The value comes from the instance metadata (site-url), set by Terraform from
# var.domain_names. It is checked here because it is written into PHP code, and passed to Python as
# an environment variable, never inside the script text. The block is replaced on every boot, so a
# changed domain takes effect when the instance is recreated.
SITE_URL=$(metadata site-url)
if ! [[ "$SITE_URL" =~ ^https://[a-z0-9.-]+$ ]]; then
  echo ">>> ERROR: site-url '$SITE_URL' is not an https:// URL with a plain hostname." >&2
  exit 1
fi
SITE_URL="$SITE_URL" python3 <<'PYEOF'
import os
import re
import sys

path = '/var/www/html/wp-config.php'
marker = "/* That's all, stop editing!"
start = "/* Site address, set by the startup script from the instance metadata (site-url). */"
end = "/* End of site address. */"
url = os.environ['SITE_URL']
block = (
    start + "\n"
    "define( 'WP_HOME', '" + url + "' );\n"
    "define( 'WP_SITEURL', '" + url + "' );\n"
    + end + "\n\n"
)

with open(path, 'r') as f:
    content = f.read()

content = re.sub(re.escape(start) + r".*?" + re.escape(end) + r"\n\n", "", content, flags=re.S)
if marker not in content:
    sys.exit(f"ERROR: {marker!r} not found in {path}.")
content = content.replace(marker, block + marker, 1)

with open(path, 'w') as f:
    f.write(content)
PYEOF

echo ">>> Mounting the uploads bucket..."
# The bucket name and the folder to mount come from the instance metadata (keys uploads-bucket and
# uploads-folder). The mount is gone after a reboot and this script runs again on every boot, so it
# is mounted here and not in /etc/fstab.
#   --only-dir       mounts only the uploads folder of the bucket (wp-content/uploads), so objects are
#                    stored under the same path WordPress serves them from:
#                    wp-content/uploads/2026/10/photo.jpg.
#   --implicit-dirs  shows folders that exist only as a prefix of object names, for example
#                    uploads copied straight into the bucket with gcloud when restoring a backup.
#   -o allow_other   this script runs as root; Apache, as www-data, must be able to use the mount.
#   --uid / --gid    files and folders appear owned by www-data, so WordPress can write uploads.
# If the mount fails the script stops before the readiness marker, and the instance is replaced.
UPLOADS_BUCKET=$(metadata uploads-bucket)
UPLOADS_FOLDER=$(metadata uploads-folder)
UPLOADS_DIR="/var/www/html/wp-content/uploads"

if ! mountpoint -q "$UPLOADS_DIR"; then
  gcsfuse \
    --only-dir "$UPLOADS_FOLDER" \
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
