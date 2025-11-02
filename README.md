# Nextcloud Server Community Edition - Installeur Automatisé

Installation automatisée de **Nextcloud Server Community Edition** sur **Debian 13** avec support de **Nextcloud Office** (Collabora Online) et **Nextcloud Talk**.

## 📋 Fonctionnalités

- ✅ Installation complète de Nextcloud Server
- ✅ Support de **Nextcloud Office** (suite bureautique avec Collabora Online)
- ✅ Support de **Nextcloud Talk** (visioconférence et messagerie)
- ✅ Configuration Apache + PHP (version par défaut du système)
- ✅ Base de données MariaDB ou PostgreSQL
- ✅ Cache Redis pour performances optimales
- ✅ Support du reverse proxy (Nginx, Caddy, Traefik, HAProxy)
- ✅ Configuration automatique du HTTPS via reverse proxy
- ✅ Génération automatique des mots de passe sécurisés
- ✅ Déploiement manuel (script Bash) ou automatisé (Ansible)
- ✅ Configuration des tâches cron pour maintenance
- ✅ Fichier d'informations avec tous les credentials

## 🚀 Installation Rapide

### Méthode 1 : Installation via curl (recommandée)

```bash
# Installation basique
curl -fsSL https://raw.githubusercontent.com/tiagomatiastm-prog/nextcloud-installer/master/install-nextcloud.sh | \
  sudo bash -s -- --domain cloud.example.com --email admin@example.com

# Installation avec Nextcloud Office et Talk
curl -fsSL https://raw.githubusercontent.com/tiagomatiastm-prog/nextcloud-installer/master/install-nextcloud.sh | \
  sudo bash -s -- \
    --domain cloud.example.com \
    --email admin@example.com \
    --install-office \
    --install-talk \
    --reverse-proxy

# Installation avec PostgreSQL
curl -fsSL https://raw.githubusercontent.com/tiagomatiastm-prog/nextcloud-installer/master/install-nextcloud.sh | \
  sudo bash -s -- \
    --domain cloud.example.com \
    --email admin@example.com \
    --db-type pgsql
```

### Méthode 2 : Installation manuelle

```bash
# Télécharger le script
wget https://raw.githubusercontent.com/tiagomatiastm-prog/nextcloud-installer/master/install-nextcloud.sh
chmod +x install-nextcloud.sh

# Exécuter avec options
sudo ./install-nextcloud.sh \
  --domain cloud.example.com \
  --email admin@example.com \
  --install-office \
  --install-talk
```

### Méthode 3 : Déploiement avec Ansible

Voir [DEPLOYMENT.md](DEPLOYMENT.md) pour les instructions détaillées.

## ⚙️ Options de Configuration

### Arguments en ligne de commande

| Option | Description | Défaut |
|--------|-------------|--------|
| `--domain DOMAIN` | Nom de domaine | `nextcloud.local` |
| `--email EMAIL` | Email administrateur | `admin@localhost` |
| `--reverse-proxy` | Activer le mode reverse proxy | `false` |
| `--bind-address ADDRESS` | Adresse d'écoute | `0.0.0.0` (ou `127.0.0.1` si reverse proxy) |
| `--port PORT` | Port HTTP | `80` |
| `--db-type TYPE` | Type de BDD (`mysql` ou `pgsql`) | `mysql` |
| `--install-office` | Installer Nextcloud Office | `false` |
| `--install-talk` | Installer Nextcloud Talk | `false` |
| `--data-dir DIR` | Répertoire de données | `/var/www/nextcloud/data` |

### Variables d'environnement

Vous pouvez également utiliser des variables d'environnement :

```bash
export NC_DOMAIN="cloud.example.com"
export NC_EMAIL="admin@example.com"
export NC_REVERSE_PROXY="true"
export NC_INSTALL_OFFICE="true"
export NC_INSTALL_TALK="true"

curl -fsSL https://raw.githubusercontent.com/tiagomatiastm-prog/nextcloud-installer/master/install-nextcloud.sh | sudo bash
```

## 🔧 Composants Installés

### Nextcloud Server
- **Version** : Dernière version stable (Nextcloud 32)
- **PHP** : Version par défaut du système (PHP 8.4 sur Debian 13) avec extensions nécessaires
- **Serveur Web** : Apache avec mod_rewrite
- **Cache** : Redis + APCu
- **Base de données** : MariaDB ou PostgreSQL

### Nextcloud Office (Collabora Online)
- Suite bureautique en ligne (Writer, Calc, Impress)
- Édition collaborative de documents
- Support des formats Microsoft Office et LibreOffice
- Déployé via Docker

### Nextcloud Talk
- Visioconférence HD
- Messagerie instantanée
- Partage d'écran
- Server TURN/STUN (coturn) pour NAT traversal

## 📦 Ports Utilisés

| Service | Port | Description |
|---------|------|-------------|
| Apache/Nextcloud | 80 (défaut) | Interface web principale |
| Collabora Online | 9980 | API Collabora (si installé) |
| coturn (STUN) | 3478 | STUN pour Talk (UDP/TCP) |
| coturn (TURN TLS) | 5349 | TURN over TLS pour Talk |

## 🔐 Sécurité

Après l'installation, un fichier `~/nextcloud-info.txt` est créé avec :
- URL d'accès
- Credentials administrateur
- Mots de passe des bases de données
- Informations Redis
- Credentials Collabora (si installé)
- Secret TURN (si installé)

### Recommandations de sécurité

1. **Changez le mot de passe admin** après la première connexion
2. **Configurez HTTPS** avec Let's Encrypt (voir [REVERSE_PROXY.md](REVERSE_PROXY.md))
3. **Activez l'authentification à deux facteurs** (2FA)
4. **Configurez un pare-feu** (UFW, iptables)
5. **Sauvegardez régulièrement** la base de données et les données

## 🔄 Mise à jour

Pour mettre à jour Nextcloud :

```bash
cd /var/www/nextcloud
sudo -u www-data php occ maintenance:mode --on
sudo -u www-data php occ upgrade
sudo -u www-data php occ maintenance:mode --off
```

## 🛠️ Commandes Utiles

```bash
# Status des services
systemctl status apache2
systemctl status redis-server
docker ps | grep collabora  # Si Collabora installé
systemctl status coturn      # Si Talk installé

# Logs
tail -f /var/log/apache2/nextcloud_error.log
docker logs -f collabora     # Logs Collabora
journalctl -u coturn -f      # Logs coturn

# Commandes OCC (Nextcloud CLI)
cd /var/www/nextcloud
sudo -u www-data php occ status
sudo -u www-data php occ app:list
sudo -u www-data php occ files:scan --all
sudo -u www-data php occ config:list system

# Maintenance
sudo -u www-data php occ maintenance:mode --on
sudo -u www-data php occ maintenance:mode --off
sudo -u www-data php occ maintenance:repair
```

## 🌐 Configuration Reverse Proxy

Pour utiliser Nextcloud derrière un reverse proxy (Nginx, Caddy, Traefik, HAProxy) avec HTTPS :

1. Installer avec l'option `--reverse-proxy`
2. Configurer votre reverse proxy (voir [REVERSE_PROXY.md](REVERSE_PROXY.md))
3. Configurer Let's Encrypt pour HTTPS

Le script configure automatiquement :
- Bind sur `127.0.0.1` au lieu de `0.0.0.0`
- Configuration des trusted proxies
- Configuration du protocole HTTPS
- Configuration de l'overwrite host

## 📚 Documentation Nextcloud

- **Documentation officielle** : https://docs.nextcloud.com/
- **Administration** : https://docs.nextcloud.com/server/latest/admin_manual/
- **Nextcloud Office** : https://nextcloud.com/office/
- **Nextcloud Talk** : https://nextcloud.com/talk/

## 🧪 Prérequis

- **OS** : Debian 13 (testé) ou compatible
- **RAM** : Minimum 2 GB (4 GB recommandé avec Office et Talk)
- **Disque** : Minimum 10 GB (selon volume de données)
- **Réseau** : Connexion Internet pour téléchargements

## 🐛 Dépannage

### Problème : Page blanche après installation

```bash
# Vérifier les logs Apache
tail -f /var/log/apache2/nextcloud_error.log

# Vérifier les permissions
chown -R www-data:www-data /var/www/nextcloud
```

### Problème : Erreur de connexion à la base de données

```bash
# Vérifier MariaDB
systemctl status mariadb
mysql -u nextcloud -p

# Vérifier PostgreSQL
systemctl status postgresql
sudo -u postgres psql -c "\l"
```

### Problème : Redis non accessible

```bash
# Vérifier Redis
systemctl status redis-server
redis-cli ping
```

### Problème : Collabora ne démarre pas

```bash
# Vérifier le container
docker ps -a | grep collabora
docker logs collabora

# Redémarrer
docker restart collabora
```

### Problème : Talk ne fonctionne pas

```bash
# Vérifier coturn
systemctl status coturn
sudo ss -tulpn | grep 3478

# Tester la connectivité
sudo netstat -tulpn | grep coturn
```

## 📄 Licence

Ce script est fourni "tel quel", sans garantie d'aucune sorte.

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Signaler des bugs
- Proposer des améliorations
- Soumettre des pull requests

## 📞 Support

Pour toute question ou problème :
1. Consultez la documentation Nextcloud officielle
2. Vérifiez les logs (`~/nextcloud-info.txt` pour les emplacements)
3. Ouvrez une issue sur GitHub

---

**Nextcloud** est une marque déposée de Nextcloud GmbH.
