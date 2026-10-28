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

echo ">>> Downloading WordPress and its language packs..."
# Every download is pinned to an exact version and checked against the SHA256 in checksums.sha256,
# committed in the repository (uploaded to /tmp by the Packer template). Nothing is extracted until
# every file matches: sha256sum --strict fails on any mismatch or missing file, and set -e stops
# the build.
#
# WordPress publishes only SHA1 and MD5 for its releases. The SHA256 committed here was computed
# from the release archive after checking it against the official SHA1:
#   https://wordpress.org/wordpress-<version>.tar.gz.sha1
#
# Language packs come from the same place WP-CLI downloads them (wp language core install), listed
# by the WordPress.org translations API:
#   https://api.wordpress.org/translations/core/1.0/?version=<version>
#   https://api.wordpress.org/translations/themes/1.0/?slug=twentytwentyfive
# They are installed here and not from the admin panel: DISALLOW_FILE_MODS (below) turns off
# language pack installs, and a pack installed on one instance would be lost when the MIG replaces
# it. The site language is chosen after the installation, in Settings > General > Site Language,
# which lists the languages installed on disk. Pack versions follow the WordPress version (core)
# and the theme version (Twenty Twenty-Five, the default theme). WordPress.org rebuilds a pack when
# its translations change, without a new version: the build then fails on its checksum, and the
# new pack must be reviewed and its SHA256 updated.
#
# To upgrade: change the versions or locales below, then run, from the repository root,
#   bash packer/scripts/update-checksums.sh
# which checks the WordPress archive against its official SHA1, checks THEME_VERSION against the
# theme bundled in that release, and rewrites checksums.sha256. The variables below must stay in
# the form VAR="value": that script reads them from this file. Twenty Twenty-Five has no es_AR
# translation, so that language is in CORE_LOCALES only.
WP_VERSION="7.1.3"
THEME_SLUG="twentytwentyfive"
THEME_VERSION="1.5"
CORE_LOCALES="es_ES es_AR de_DE fr_FR it_IT ja nl_NL pl_PL pt_BR ru_RU"
THEME_LOCALES="es_ES de_DE fr_FR it_IT ja nl_NL pl_PL pt_BR ru_RU"

DOWNLOADS=/tmp/downloads
mkdir -p "$DOWNLOADS"
curl -fsSL -o "$DOWNLOADS/wordpress-${WP_VERSION}.tar.gz" "https://wordpress.org/wordpress-${WP_VERSION}.tar.gz"
for locale in $CORE_LOCALES; do
  curl -fsSL -o "$DOWNLOADS/wordpress-${WP_VERSION}-${locale}.zip" \
    "https://downloads.wordpress.org/translation/core/${WP_VERSION}/${locale}.zip"
done
for locale in $THEME_LOCALES; do
  curl -fsSL -o "$DOWNLOADS/${THEME_SLUG}-${THEME_VERSION}-${locale}.zip" \
    "https://downloads.wordpress.org/translation/theme/${THEME_SLUG}/${THEME_VERSION}/${locale}.zip"
done
(cd "$DOWNLOADS" && sha256sum --strict -c /tmp/checksums.sha256)

cd /var/www/html
tar -xzf "$DOWNLOADS/wordpress-${WP_VERSION}.tar.gz"
cp -rf wordpress/* .
rm -rf wordpress
rm -f index.html
grep -q "wp_version = '${WP_VERSION}'" wp-includes/version.php

mkdir -p wp-content/languages/themes
for locale in $CORE_LOCALES; do
  unzip -oq "$DOWNLOADS/wordpress-${WP_VERSION}-${locale}.zip" -d wp-content/languages
done
for locale in $THEME_LOCALES; do
  unzip -oq "$DOWNLOADS/${THEME_SLUG}-${THEME_VERSION}-${locale}.zip" -d wp-content/languages/themes
done
rm -rf "$DOWNLOADS"

echo ">>> Disabling application passwords..."
# Application passwords authenticate the REST API and XML-RPC with HTTP Basic Auth. The REST API
# (/wp-json/) is served by the public backend, so one of them would reach WordPress as an
# authenticated user without going through IAP, which protects only the admin area and the login.
# WordPress has no constant for this; the filter is the documented way to turn the feature off:
#   https://make.wordpress.org/core/2020/11/05/application-passwords-integration-guide/
# A must-use plugin is loaded on every request and cannot be deactivated from the admin panel.
mkdir -p wp-content/mu-plugins
cat > wp-content/mu-plugins/disable-application-passwords.php <<'PHPEOF'
<?php
/*
 * Plugin Name: Disable application passwords
 * Description: Application passwords would authenticate the REST API without going through IAP.
 */
add_filter( 'wp_is_application_passwords_available', '__return_false' );
PHPEOF

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

echo ">>> Disk usage of the image..."
# Recorded in the build log, to see how much of the disk the image uses.
df -h /
du -sh /var/www/html /var/www/html/wp-content/languages

echo ">>> Build complete"