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

echo ">>> Setting permissions..."
chown -R www-data:www-data /var/www/html

echo ">>> Enabling services on boot..."
systemctl enable apache2

echo ">>> Build complete"