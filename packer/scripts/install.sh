#!/bin/bash
# packer/scripts/install.sh
set -e
set -x

echo ">>> Updating system..."
apt-get update -y
apt-get upgrade -y

echo ">>> Installing stack..."
apt-get install -y \
  apache2 \
  php \
  php-mysql \
  libapache2-mod-php \
  wget curl unzip

echo ">>> Installing Cloud Storage FUSE..."
# Mounts the uploads bucket at wp-content/uploads (done at boot by the startup script, which knows
# the bucket name). Installed from Google's apt repository: apt verifies the signature of every
# package against the repository key, so no separate checksum is needed. The version is pinned;
# to upgrade, change GCSFUSE_VERSION. The available versions are listed in the build log.
GCSFUSE_VERSION="3.12.1"
. /etc/os-release
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg -o /usr/share/keyrings/cloud.google.asc
echo "deb [signed-by=/usr/share/keyrings/cloud.google.asc] https://packages.cloud.google.com/apt gcsfuse-${VERSION_CODENAME} main" \
  > /etc/apt/sources.list.d/gcsfuse.list
apt-get update -y
apt-cache madison gcsfuse | head -n 5
apt-get install -y "gcsfuse=${GCSFUSE_VERSION}"

echo ">>> Downloading WordPress..."
cd /var/www/html
curl -O https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -rf wordpress/* .
rm -rf wordpress latest.tar.gz
rm -f index.html

# Leave wp-config-sample intact — credentials
# will be injected at runtime via startup script
cp wp-config-sample.php wp-config.php

echo ">>> Configuring WordPress for the HTTPS load balancer..."
# TLS ends at the load balancer, so every request reaches Apache over plain HTTP and WordPress
# believes the visitor is not on HTTPS: it builds http:// asset URLs and redirects the admin
# area in a loop. The block below makes it read the X-Forwarded-Proto header the load balancer
# sets. It is static configuration, not a secret, so it belongs in the image.
# It must sit before wp-settings.php is loaded; the "stop editing" comment marks that place.
# The build fails if that comment is not found, instead of producing an image without the block.
python3 <<'PYEOF'
import sys

path = '/var/www/html/wp-config.php'
marker = "/* That's all, stop editing!"
block = """/* Behind the HTTPS load balancer: TLS ends at the load balancer and requests reach
   Apache over plain HTTP. Trust the X-Forwarded-Proto header the load balancer sets,
   so WordPress knows the visitor is on HTTPS. */
if ( isset( $_SERVER['HTTP_X_FORWARDED_PROTO'] ) && strpos( $_SERVER['HTTP_X_FORWARDED_PROTO'], 'https' ) !== false ) {
    $_SERVER['HTTPS'] = 'on';
}
define( 'FORCE_SSL_ADMIN', true );

/* Immutable instances: plugins and themes come with the image. The admin panel cannot install,
   update or edit them, because a change made there would exist on one instance only and be lost
   when the MIG replaces it. Uploads are not affected. */
define( 'DISALLOW_FILE_MODS', true );

"""

with open(path, 'r') as f:
    content = f.read()

if marker not in content:
    sys.exit(f"ERROR: {marker!r} not found in {path}. wp-config-sample.php changed: update install.sh.")

content = content.replace(marker, block + marker, 1)

with open(path, 'w') as f:
    f.write(content)
PYEOF

echo ">>> Creating health check endpoint..."
# Healthy only once the startup script has finished configuring WordPress and left its marker.
# An instance whose startup failed answers 503: the load balancer sends it no traffic and the
# MIG auto-healing replaces it. The marker means "configured", not "database reachable": tying
# health to the database would make every instance unhealthy at once during a database outage.
# /run is cleared on reboot, and the startup script runs again on every boot.
cat > /var/www/html/health.php <<'PHPEOF'
<?php
if ( file_exists( '/run/wordpress-configured' ) ) {
    http_response_code( 200 );
    echo 'ok';
} else {
    http_response_code( 503 );
    echo 'not configured';
}
PHPEOF

echo ">>> Creating the uploads mount point..."
# The startup script mounts the uploads bucket here. Nothing is stored in it in the image.
mkdir -p /var/www/html/wp-content/uploads

echo ">>> Setting permissions..."
chown -R www-data:www-data /var/www/html

echo ">>> Enabling services on boot..."
systemctl enable apache2

echo ">>> Build complete"