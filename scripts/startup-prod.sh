#!/bin/bash
set -e

# --- CONFIGURACIÓN (Variables que podrías pasar por Metadata) ---
DB_NAME="wordpress_db"
DB_USER="wordpress_user"
DB_PASS="tu_password_segura"
DB_HOST="10.x.x.x"  # <--- REEMPLAZAR con la IP Interna de tu Cloud SQL

# Instalar pila LAMP
apt-get update
apt-get install -y apache2 php php-mysql libapache2-mod-php wget tar unzip curl

# Configurar WordPress
cd /var/www/html
curl -O https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -rf wordpress/* .
rm -rf wordpress latest.tar.gz

cp wp-config-sample.php wp-config.php

# Configurar conexión a DB (IP Interna)
sed -i "s/database_name_here/$DB_NAME/g" wp-config.php
sed -i "s/username_here/$DB_USER/g" wp-config.php
sed -i "s/password_here/$DB_PASS/g" wp-config.php
sed -i "s/localhost/$DB_HOST/g" wp-config.php

# Seguridad: Generar Salts automáticamente
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
printf '%s\n' "g/put your unique phrase here/d" a "$SALT" . w | ed -s wp-config.php

# Permisos
chown -R www-data:www-data /var/www/html
systemctl restart apache2