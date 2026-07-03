# packer/scripts/install.sh
#!/bin/bash
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

echo ">>> Creating health check endpoint..."
echo '<?php http_response_code(200); echo "ok"; ?>' > /var/www/html/health.php

echo ">>> Setting permissions..."
chown -R www-data:www-data /var/www/html

echo ">>> Enabling services on boot..."
systemctl enable apache2

echo ">>> Build complete"