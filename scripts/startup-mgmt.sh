#!/bin/bash
set -e

# --- CONFIGURACIÓN ---
DB_NAME="wordpress_db"
DB_USER="wordpress_user"
DB_PASS="tu_password_segura"
# Connection Name se saca de la consola de Cloud SQL: "project:region:instance"
INSTANCE_CONNECTION_NAME="tu-proyecto:us-central1:tu-instancia"

# 1. Instalar dependencias
apt-get update
apt-get install -y apache2 php php-mysql libapache2-mod-php wget tar unzip curl

# 2. Instalar Cloud SQL Auth Proxy
wget https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.1.0/cloud-sql-proxy.linux.amd64 -O /usr/local/bin/cloud-sql-proxy
chmod +x /usr/local/bin/cloud-sql-proxy

# 3. Crear servicio para el Proxy (para que corra en segundo plano)
cat <<EOF > /etc/systemd/system/cloud-sql-proxy.service
[Unit]
Description=Cloud SQL Auth Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/cloud-sql-proxy --address 0.0.0.0 --port 3306 $INSTANCE_CONNECTION_NAME
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloud-sql-proxy
systemctl start cloud-sql-proxy

# 4. Configurar WordPress
cd /var/www/html
curl -O https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -rf wordpress/* .
rm -rf wordpress latest.tar.gz

cp wp-config-sample.php wp-config.php

# Configurar conexión a DB (Apunta a LOCALHOST porque el Proxy está ahí)
sed -i "s/database_name_here/$DB_NAME/g" wp-config.php
sed -i "s/username_here/$DB_USER/g" wp-config.php
sed -i "s/password_here/$DB_PASS/g" wp-config.php
sed -i "s/localhost/127.0.0.1/g" wp-config.php

# Salts y permisos
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
printf '%s\n' "g/put your unique phrase here/d" a "$SALT" . w | ed -s wp-config.php

chown -R www-data:www-data /var/www/html
systemctl restart apache2