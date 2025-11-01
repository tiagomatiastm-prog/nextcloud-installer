#!/bin/bash
#
# Nextcloud Server Community Edition Installer
# Installation automatisée sur Debian 13
# Inclut Nextcloud Office (Collabora) et Nextcloud Talk
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tiagomatiastm-prog/nextcloud-installer/master/install-nextcloud.sh | sudo bash
#   ou
#   sudo bash install-nextcloud.sh [options]
#
# Options:
#   --domain DOMAIN           Nom de domaine (ex: cloud.example.com)
#   --email EMAIL             Email administrateur
#   --reverse-proxy           Activer mode reverse proxy (bind sur 127.0.0.1)
#   --bind-address ADDRESS    Adresse d'écoute (défaut: 0.0.0.0 ou 127.0.0.1 si reverse proxy)
#   --port PORT               Port HTTP (défaut: 80)
#   --db-type TYPE            Type de BDD: mysql ou pgsql (défaut: mysql)
#   --install-office          Installer Nextcloud Office (Collabora)
#   --install-talk            Installer Nextcloud Talk (coturn)
#   --data-dir DIR            Répertoire de données (défaut: /var/www/nextcloud/data)
#   -h, --help                Afficher l'aide
#

set -e

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction d'aide
show_help() {
    cat << EOF
Nextcloud Server Community Edition Installer

Usage:
  sudo bash install-nextcloud.sh [options]
  ou
  curl -fsSL https://raw.githubusercontent.com/tiagomatiastm-prog/nextcloud-installer/master/install-nextcloud.sh | sudo bash -s -- [options]

Options:
  --domain DOMAIN           Nom de domaine (ex: cloud.example.com)
  --email EMAIL             Email administrateur
  --reverse-proxy           Activer mode reverse proxy (bind sur 127.0.0.1)
  --bind-address ADDRESS    Adresse d'écoute (défaut: 0.0.0.0 ou 127.0.0.1 si reverse proxy)
  --port PORT               Port HTTP (défaut: 80)
  --db-type TYPE            Type de BDD: mysql ou pgsql (défaut: mysql)
  --install-office          Installer Nextcloud Office (Collabora)
  --install-talk            Installer Nextcloud Talk (coturn)
  --data-dir DIR            Répertoire de données (défaut: /var/www/nextcloud/data)
  -h, --help                Afficher l'aide

Variables d'environnement (alternative aux arguments):
  NC_DOMAIN                 Nom de domaine
  NC_EMAIL                  Email administrateur
  NC_REVERSE_PROXY          true pour activer le mode reverse proxy
  NC_BIND_ADDRESS           Adresse d'écoute
  NC_PORT                   Port HTTP
  NC_DB_TYPE                Type de base de données
  NC_INSTALL_OFFICE         true pour installer Collabora
  NC_INSTALL_TALK           true pour installer Talk/coturn
  NC_DATA_DIR               Répertoire de données

Exemples:
  # Installation basique
  sudo bash install-nextcloud.sh --domain cloud.example.com --email admin@example.com

  # Installation avec reverse proxy
  sudo bash install-nextcloud.sh --domain cloud.example.com --email admin@example.com --reverse-proxy

  # Installation complète avec Office et Talk
  sudo bash install-nextcloud.sh --domain cloud.example.com --email admin@example.com --install-office --install-talk

  # Via curl avec options
  curl -fsSL https://raw.githubusercontent.com/tiagomatiastm-prog/nextcloud-installer/master/install-nextcloud.sh | \\
    sudo bash -s -- --domain cloud.example.com --email admin@example.com --reverse-proxy

EOF
    exit 0
}

# Valeurs par défaut
DOMAIN="${NC_DOMAIN:-nextcloud.local}"
EMAIL="${NC_EMAIL:-admin@localhost}"
REVERSE_PROXY="${NC_REVERSE_PROXY:-false}"
BIND_ADDRESS="${NC_BIND_ADDRESS:-}"
PORT="${NC_PORT:-80}"
DB_TYPE="${NC_DB_TYPE:-mysql}"
INSTALL_OFFICE="${NC_INSTALL_OFFICE:-false}"
INSTALL_TALK="${NC_INSTALL_TALK:-false}"
DATA_DIR="${NC_DATA_DIR:-/var/www/nextcloud/data}"

# Parser les arguments CLI
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --reverse-proxy)
            REVERSE_PROXY="true"
            shift
            ;;
        --bind-address)
            BIND_ADDRESS="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --db-type)
            DB_TYPE="$2"
            shift 2
            ;;
        --install-office)
            INSTALL_OFFICE="true"
            shift
            ;;
        --install-talk)
            INSTALL_TALK="true"
            shift
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Option inconnue: $1"
            show_help
            ;;
    esac
done

# Déterminer l'adresse de bind si non spécifiée
if [ -z "$BIND_ADDRESS" ]; then
    if [ "$REVERSE_PROXY" = "true" ]; then
        BIND_ADDRESS="127.0.0.1"
    else
        BIND_ADDRESS="0.0.0.0"
    fi
fi

# Vérifier les privilèges root
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Détection de l'utilisateur réel (pour les credentials)
REAL_USER="${SUDO_USER:-root}"
if [ "$REAL_USER" = "root" ]; then
    USER_HOME="/root"
else
    USER_HOME=$(eval echo ~$REAL_USER)
fi

log_info "========================================="
log_info "Nextcloud Server Community Edition Installer"
log_info "========================================="
log_info "Domaine: $DOMAIN"
log_info "Email: $EMAIL"
log_info "Reverse proxy: $REVERSE_PROXY"
log_info "Bind address: $BIND_ADDRESS"
log_info "Port: $PORT"
log_info "Type de BDD: $DB_TYPE"
log_info "Installer Office: $INSTALL_OFFICE"
log_info "Installer Talk: $INSTALL_TALK"
log_info "Répertoire de données: $DATA_DIR"
log_info "========================================="

# Mise à jour du système
log_info "Mise à jour du système..."
apt-get update
apt-get upgrade -y

# Installation des dépendances de base
log_info "Installation des dépendances de base..."
apt-get install -y \
    wget curl sudo gnupg2 ca-certificates lsb-release \
    apt-transport-https \
    unzip bzip2 imagemagick

# Installation de PHP 8.2
log_info "Installation de PHP 8.2..."
apt-get install -y \
    php8.2 php8.2-fpm php8.2-cli \
    php8.2-gd php8.2-mysql php8.2-pgsql php8.2-curl \
    php8.2-mbstring php8.2-intl php8.2-gmp \
    php8.2-bcmath php8.2-xml php8.2-zip \
    php8.2-imagick php8.2-redis php8.2-apcu \
    php8.2-ldap php8.2-bz2

# Installation de la base de données
if [ "$DB_TYPE" = "mysql" ]; then
    log_info "Installation de MariaDB..."
    apt-get install -y mariadb-server mariadb-client
    systemctl enable mariadb
    systemctl start mariadb
elif [ "$DB_TYPE" = "pgsql" ]; then
    log_info "Installation de PostgreSQL..."
    apt-get install -y postgresql postgresql-contrib
    systemctl enable postgresql
    systemctl start postgresql
else
    log_error "Type de base de données invalide: $DB_TYPE (mysql ou pgsql)"
    exit 1
fi

# Installation de Redis
log_info "Installation de Redis..."
apt-get install -y redis-server
systemctl enable redis-server
systemctl start redis-server

# Installation d'Apache
log_info "Installation d'Apache..."
apt-get install -y apache2 libapache2-mod-php8.2

# Activation des modules Apache nécessaires
log_info "Activation des modules Apache..."
a2enmod rewrite headers env dir mime setenvif ssl
systemctl enable apache2

# Génération des mots de passe
log_info "Génération des mots de passe..."
DB_PASSWORD=$(openssl rand -base64 32)
ADMIN_PASSWORD=$(openssl rand -base64 16)

# Configuration de la base de données
if [ "$DB_TYPE" = "mysql" ]; then
    log_info "Configuration de MariaDB..."
    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'nextcloud'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;
EOF
elif [ "$DB_TYPE" = "pgsql" ]; then
    log_info "Configuration de PostgreSQL..."
    sudo -u postgres psql <<EOF
CREATE USER nextcloud WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE nextcloud OWNER nextcloud ENCODING 'UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' TEMPLATE template0;
GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;
EOF
fi

# Téléchargement de Nextcloud
log_info "Téléchargement de Nextcloud..."
NC_VERSION=$(curl -s https://download.nextcloud.com/server/releases/ | grep -oP 'latest-[0-9]+\.tar\.bz2' | head -1)
if [ -z "$NC_VERSION" ]; then
    NC_VERSION="latest.tar.bz2"
fi
log_info "Version Nextcloud: $NC_VERSION"

cd /tmp
wget -O nextcloud.tar.bz2 "https://download.nextcloud.com/server/releases/$NC_VERSION"

# Extraction de Nextcloud
log_info "Extraction de Nextcloud..."
tar -xjf nextcloud.tar.bz2
mv nextcloud /var/www/

# Création du répertoire de données
log_info "Création du répertoire de données: $DATA_DIR"
mkdir -p "$DATA_DIR"

# Configuration des permissions
log_info "Configuration des permissions..."
chown -R www-data:www-data /var/www/nextcloud
chown -R www-data:www-data "$DATA_DIR"

# Configuration PHP
log_info "Configuration PHP..."
PHP_INI="/etc/php/8.2/fpm/php.ini"
sed -i 's/memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 10G/' "$PHP_INI"
sed -i 's/post_max_size = .*/post_max_size = 10G/' "$PHP_INI"
sed -i 's/max_execution_time = .*/max_execution_time = 3600/' "$PHP_INI"
sed -i 's/max_input_time = .*/max_input_time = 3600/' "$PHP_INI"
sed -i 's/;opcache.enable=.*/opcache.enable=1/' "$PHP_INI"
sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=128/' "$PHP_INI"
sed -i 's/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=8/' "$PHP_INI"
sed -i 's/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' "$PHP_INI"
sed -i 's/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/' "$PHP_INI"
sed -i 's/;opcache.save_comments=.*/opcache.save_comments=1/' "$PHP_INI"

# Configuration Apache
log_info "Configuration Apache..."
cat > /etc/apache2/sites-available/nextcloud.conf <<EOF
<VirtualHost $BIND_ADDRESS:$PORT>
    ServerName $DOMAIN
    DocumentRoot /var/www/nextcloud

    <Directory /var/www/nextcloud/>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted

        <IfModule mod_dav.c>
            Dav off
        </IfModule>

        SetEnv HOME /var/www/nextcloud
        SetEnv HTTP_HOME /var/www/nextcloud
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
EOF

# Désactiver le site par défaut et activer Nextcloud
a2dissite 000-default.conf || true
a2ensite nextcloud.conf

# Configuration Redis pour Nextcloud
log_info "Configuration Redis..."
REDIS_PASSWORD=$(openssl rand -base64 32)
cat >> /etc/redis/redis.conf <<EOF

# Nextcloud configuration
requirepass $REDIS_PASSWORD
EOF

systemctl restart redis-server

# Installation de Nextcloud via occ
log_info "Installation de Nextcloud..."
cd /var/www/nextcloud

if [ "$DB_TYPE" = "mysql" ]; then
    sudo -u www-data php occ maintenance:install \
        --database "mysql" \
        --database-name "nextcloud" \
        --database-user "nextcloud" \
        --database-pass "$DB_PASSWORD" \
        --admin-user "admin" \
        --admin-pass "$ADMIN_PASSWORD" \
        --data-dir "$DATA_DIR"
elif [ "$DB_TYPE" = "pgsql" ]; then
    sudo -u www-data php occ maintenance:install \
        --database "pgsql" \
        --database-name "nextcloud" \
        --database-user "nextcloud" \
        --database-pass "$DB_PASSWORD" \
        --database-host "localhost" \
        --admin-user "admin" \
        --admin-pass "$ADMIN_PASSWORD" \
        --data-dir "$DATA_DIR"
fi

# Configuration des trusted domains
log_info "Configuration des trusted domains..."
sudo -u www-data php occ config:system:set trusted_domains 0 --value="$DOMAIN"
sudo -u www-data php occ config:system:set trusted_domains 1 --value="localhost"

# Configuration Redis
log_info "Configuration Redis pour Nextcloud..."
sudo -u www-data php occ config:system:set redis host --value="localhost"
sudo -u www-data php occ config:system:set redis port --value=6379
sudo -u www-data php occ config:system:set redis password --value="$REDIS_PASSWORD"
sudo -u www-data php occ config:system:set memcache.local --value="\OC\Memcache\APCu"
sudo -u www-data php occ config:system:set memcache.distributed --value="\OC\Memcache\Redis"
sudo -u www-data php occ config:system:set memcache.locking --value="\OC\Memcache\Redis"

# Configuration du reverse proxy si nécessaire
if [ "$REVERSE_PROXY" = "true" ]; then
    log_info "Configuration du mode reverse proxy..."
    sudo -u www-data php occ config:system:set overwriteprotocol --value="https"
    sudo -u www-data php occ config:system:set overwritehost --value="$DOMAIN"
    sudo -u www-data php occ config:system:set overwrite.cli.url --value="https://$DOMAIN"
    sudo -u www-data php occ config:system:set trusted_proxies 0 --value="127.0.0.1"
fi

# Installation de Nextcloud Office (Collabora) si demandé
if [ "$INSTALL_OFFICE" = "true" ]; then
    log_info "Installation de Nextcloud Office (Collabora)..."

    # Installation de Docker si nécessaire
    if ! command -v docker &> /dev/null; then
        log_info "Installation de Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    fi

    # Installation de Collabora Online
    log_info "Déploiement du container Collabora..."
    COLLABORA_PASSWORD=$(openssl rand -base64 32)

    docker run -d \
        --name collabora \
        --restart always \
        -p 9980:9980 \
        -e "domain=$DOMAIN" \
        -e "username=admin" \
        -e "password=$COLLABORA_PASSWORD" \
        -e "extra_params=--o:ssl.enable=false --o:ssl.termination=true" \
        collabora/code:latest

    # Installation de l'app Nextcloud Office
    sudo -u www-data php occ app:install richdocuments
    sudo -u www-data php occ app:enable richdocuments

    # Configuration de Collabora
    if [ "$REVERSE_PROXY" = "true" ]; then
        sudo -u www-data php occ config:app:set richdocuments wopi_url --value="https://$DOMAIN"
    else
        sudo -u www-data php occ config:app:set richdocuments wopi_url --value="http://$DOMAIN:9980"
    fi

    log_info "Collabora Online installé et configuré"
fi

# Installation de Nextcloud Talk si demandé
if [ "$INSTALL_TALK" = "true" ]; then
    log_info "Installation de Nextcloud Talk..."

    # Installation de coturn (TURN/STUN server)
    apt-get install -y coturn

    # Génération du secret pour coturn
    TURN_SECRET=$(openssl rand -hex 32)

    # Configuration de coturn
    cat > /etc/turnserver.conf <<EOF
# Nextcloud Talk coturn configuration
listening-port=3478
tls-listening-port=5349
fingerprint
use-auth-secret
static-auth-secret=$TURN_SECRET
realm=$DOMAIN
total-quota=100
bps-capacity=0
stale-nonce
cert=/etc/ssl/certs/ssl-cert-snakeoil.pem
pkey=/etc/ssl/private/ssl-cert-snakeoil.key
no-loopback-peers
no-multicast-peers
EOF

    # Activer coturn
    sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn
    systemctl enable coturn
    systemctl restart coturn

    # Installation de l'app Talk
    sudo -u www-data php occ app:install spreed
    sudo -u www-data php occ app:enable spreed

    # Configuration de Talk
    sudo -u www-data php occ config:app:set spreed stun_servers --value="$DOMAIN:3478"
    sudo -u www-data php occ config:app:set spreed turn_servers --value='[{"server":"'$DOMAIN'","secret":"'$TURN_SECRET'","protocols":"udp,tcp"}]'

    log_info "Nextcloud Talk installé et configuré"
fi

# Configuration des tâches cron
log_info "Configuration des tâches cron..."
sudo -u www-data php occ background:cron

# Ajout du cron job
(crontab -u www-data -l 2>/dev/null; echo "*/5 * * * * php -f /var/www/nextcloud/cron.php") | crontab -u www-data -

# Redémarrage des services
log_info "Redémarrage des services..."
systemctl restart php8.2-fpm
systemctl restart apache2

# Création du fichier d'informations
INFO_FILE="$USER_HOME/nextcloud-info.txt"
log_info "Création du fichier d'informations: $INFO_FILE"

cat > "$INFO_FILE" <<EOF
========================================
Nextcloud Server - Informations d'installation
========================================

Installation terminée le: $(date)

ACCÈS WEB:
----------
EOF

if [ "$REVERSE_PROXY" = "true" ]; then
    cat >> "$INFO_FILE" <<EOF
URL: https://$DOMAIN
Note: Accès via reverse proxy (bind sur 127.0.0.1:$PORT)
Configurez votre reverse proxy pour rediriger vers http://127.0.0.1:$PORT
EOF
else
    cat >> "$INFO_FILE" <<EOF
URL: http://$DOMAIN:$PORT
Note: Accès direct (bind sur $BIND_ADDRESS:$PORT)
EOF
fi

cat >> "$INFO_FILE" <<EOF

CREDENTIALS ADMINISTRATEUR:
--------------------------
Username: admin
Password: $ADMIN_PASSWORD

BASE DE DONNÉES:
----------------
Type: $DB_TYPE
Database: nextcloud
User: nextcloud
Password: $DB_PASSWORD

REDIS:
------
Password: $REDIS_PASSWORD

RÉPERTOIRE DE DONNÉES:
---------------------
$DATA_DIR

EOF

if [ "$INSTALL_OFFICE" = "true" ]; then
    cat >> "$INFO_FILE" <<EOF
NEXTCLOUD OFFICE (COLLABORA):
-----------------------------
Container: collabora
Port: 9980
Username: admin
Password: $COLLABORA_PASSWORD

EOF
fi

if [ "$INSTALL_TALK" = "true" ]; then
    cat >> "$INFO_FILE" <<EOF
NEXTCLOUD TALK:
---------------
TURN/STUN Server: coturn
Ports: 3478 (UDP/TCP), 5349 (TLS)
Secret: $TURN_SECRET

EOF
fi

cat >> "$INFO_FILE" <<EOF
COMMANDES UTILES:
-----------------
# Status Apache
systemctl status apache2

# Logs Apache
tail -f /var/log/apache2/nextcloud_error.log

# Commandes OCC (Nextcloud)
cd /var/www/nextcloud
sudo -u www-data php occ status
sudo -u www-data php occ maintenance:mode --on
sudo -u www-data php occ maintenance:mode --off

# Mise à jour Nextcloud
sudo -u www-data php occ upgrade

# Scanner les fichiers
sudo -u www-data php occ files:scan --all

EOF

if [ "$INSTALL_OFFICE" = "true" ]; then
    cat >> "$INFO_FILE" <<EOF
# Redémarrer Collabora
docker restart collabora

# Logs Collabora
docker logs -f collabora

EOF
fi

if [ "$INSTALL_TALK" = "true" ]; then
    cat >> "$INFO_FILE" <<EOF
# Status coturn
systemctl status coturn

# Logs coturn
journalctl -u coturn -f

EOF
fi

cat >> "$INFO_FILE" <<EOF
CONFIGURATION REVERSE PROXY:
----------------------------
Voir REVERSE_PROXY.md pour exemples de configuration Nginx, Caddy, etc.

SÉCURITÉ:
---------
⚠️  Changez le mot de passe admin après la première connexion !
⚠️  Configurez HTTPS pour la production (Let's Encrypt recommandé)
⚠️  Sauvegardez régulièrement la base de données et les données

========================================
EOF

# Affichage des informations
cat "$INFO_FILE"

log_info ""
log_info "========================================="
log_info "Installation terminée avec succès !"
log_info "========================================="
log_info "Fichier d'informations: $INFO_FILE"
log_info ""
if [ "$REVERSE_PROXY" = "true" ]; then
    log_info "Nextcloud est accessible via reverse proxy sur: https://$DOMAIN"
    log_info "Service local: http://127.0.0.1:$PORT"
else
    log_info "Nextcloud est accessible sur: http://$DOMAIN:$PORT"
fi
log_info "Username: admin"
log_info "Password: $ADMIN_PASSWORD"
log_info ""
log_warn "⚠️  Changez le mot de passe admin après la première connexion !"
log_warn "⚠️  Configurez HTTPS pour la production !"
log_info "========================================="
