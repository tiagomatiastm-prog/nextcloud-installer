# Guide de Déploiement Ansible - Nextcloud Server

Ce guide explique comment déployer Nextcloud Server Community Edition sur un ou plusieurs serveurs en utilisant Ansible.

## 📋 Prérequis

### Sur la machine de contrôle (là où vous exécutez Ansible)

```bash
# Installation d'Ansible
sudo apt update
sudo apt install -y ansible

# Vérification
ansible --version
```

### Sur les serveurs cibles

- **OS** : Debian 13 ou compatible
- **Accès SSH** : Clé SSH configurée
- **Utilisateur** : avec privilèges sudo
- **Python** : Python 3 installé

## 🔧 Configuration

### 1. Cloner le dépôt

```bash
git clone https://github.com/tiagomatiastm-prog/nextcloud-installer.git
cd nextcloud-installer
```

### 2. Configurer l'inventaire

Éditez le fichier `inventory.ini` :

```ini
[nextcloud_servers]
# Serveur de production
cloud.example.com ansible_user=debian ansible_ssh_private_key_file=~/.ssh/id_rsa

# Ou avec IP
192.168.1.100 ansible_user=debian ansible_ssh_private_key_file=~/.ssh/id_rsa

# Pour un déploiement local
# localhost ansible_connection=local
```

### 3. Tester la connexion

```bash
ansible -i inventory.ini nextcloud_servers -m ping
```

## 🚀 Déploiement

### Configuration via variables d'environnement

Les variables suivantes peuvent être définies avant l'exécution du playbook :

| Variable | Description | Défaut |
|----------|-------------|--------|
| `NC_DOMAIN` | Nom de domaine | `nextcloud.local` |
| `NC_EMAIL` | Email administrateur | `admin@localhost` |
| `NC_REVERSE_PROXY` | Mode reverse proxy (`true`/`false`) | `false` |
| `NC_BIND_ADDRESS` | Adresse d'écoute | Auto (selon reverse proxy) |
| `NC_PORT` | Port HTTP | `80` |
| `NC_DB_TYPE` | Type de BDD (`mysql` ou `pgsql`) | `mysql` |
| `NC_INSTALL_OFFICE` | Installer Nextcloud Office (`true`/`false`) | `false` |
| `NC_INSTALL_TALK` | Installer Nextcloud Talk (`true`/`false`) | `false` |
| `NC_DATA_DIR` | Répertoire de données | `/var/www/nextcloud/data` |

### Méthode 1 : Via variables d'environnement

```bash
# Configuration de base
export NC_DOMAIN="cloud.example.com"
export NC_EMAIL="admin@example.com"

# Exécution
ansible-playbook -i inventory.ini deploy-nextcloud.yml
```

### Méthode 2 : Via fichier de variables

Créez un fichier `vars.yml` :

```yaml
nextcloud_domain: "cloud.example.com"
nextcloud_email: "admin@example.com"
nextcloud_reverse_proxy: "true"
nextcloud_install_office: "true"
nextcloud_install_talk: "true"
```

Exécutez avec :

```bash
ansible-playbook -i inventory.ini deploy-nextcloud.yml -e @vars.yml
```

### Méthode 3 : Variables en ligne de commande

```bash
ansible-playbook -i inventory.ini deploy-nextcloud.yml \
  -e "nextcloud_domain=cloud.example.com" \
  -e "nextcloud_email=admin@example.com" \
  -e "nextcloud_reverse_proxy=true" \
  -e "nextcloud_install_office=true"
```

## 📝 Exemples de Déploiement

### Exemple 1 : Installation basique

```bash
export NC_DOMAIN="cloud.example.com"
export NC_EMAIL="admin@example.com"

ansible-playbook -i inventory.ini deploy-nextcloud.yml
```

### Exemple 2 : Installation avec Nextcloud Office

```bash
export NC_DOMAIN="cloud.example.com"
export NC_EMAIL="admin@example.com"
export NC_INSTALL_OFFICE="true"

ansible-playbook -i inventory.ini deploy-nextcloud.yml
```

### Exemple 3 : Installation complète (Office + Talk + Reverse Proxy)

```bash
export NC_DOMAIN="cloud.example.com"
export NC_EMAIL="admin@example.com"
export NC_REVERSE_PROXY="true"
export NC_INSTALL_OFFICE="true"
export NC_INSTALL_TALK="true"

ansible-playbook -i inventory.ini deploy-nextcloud.yml
```

### Exemple 4 : Installation avec PostgreSQL

```bash
export NC_DOMAIN="cloud.example.com"
export NC_EMAIL="admin@example.com"
export NC_DB_TYPE="pgsql"

ansible-playbook -i inventory.ini deploy-nextcloud.yml
```

### Exemple 5 : Répertoire de données personnalisé

```bash
export NC_DOMAIN="cloud.example.com"
export NC_EMAIL="admin@example.com"
export NC_DATA_DIR="/data/nextcloud"

ansible-playbook -i inventory.ini deploy-nextcloud.yml
```

## 🔍 Vérification Post-Déploiement

### 1. Vérifier les services

```bash
ansible -i inventory.ini nextcloud_servers -a "systemctl status apache2" -b
ansible -i inventory.ini nextcloud_servers -a "systemctl status redis-server" -b
```

### 2. Vérifier le fichier d'informations

```bash
ansible -i inventory.ini nextcloud_servers -a "cat ~/nextcloud-info.txt"
```

### 3. Tester l'accès web

```bash
# Si pas de reverse proxy
curl -I http://cloud.example.com

# Si reverse proxy (depuis le serveur)
ssh cloud.example.com "curl -I http://127.0.0.1"
```

## 🔄 Déploiement sur Plusieurs Serveurs

Pour déployer sur plusieurs serveurs :

```ini
[nextcloud_servers]
cloud1.example.com ansible_user=debian
cloud2.example.com ansible_user=debian
cloud3.example.com ansible_user=debian
```

Exécutez le playbook normalement :

```bash
ansible-playbook -i inventory.ini deploy-nextcloud.yml
```

### Déploiement sur un serveur spécifique

```bash
ansible-playbook -i inventory.ini deploy-nextcloud.yml --limit cloud1.example.com
```

## 🛠️ Mode Dry-Run (Check)

Pour vérifier les changements sans les appliquer :

```bash
ansible-playbook -i inventory.ini deploy-nextcloud.yml --check
```

## 📊 Verbose Mode

Pour plus de détails lors de l'exécution :

```bash
# Niveau 1 (basique)
ansible-playbook -i inventory.ini deploy-nextcloud.yml -v

# Niveau 2 (détaillé)
ansible-playbook -i inventory.ini deploy-nextcloud.yml -vv

# Niveau 3 (debug)
ansible-playbook -i inventory.ini deploy-nextcloud.yml -vvv
```

## 🔐 Gestion des Secrets

### Utiliser Ansible Vault pour les secrets

```bash
# Créer un fichier de secrets chiffré
ansible-vault create secrets.yml

# Contenu du fichier
nextcloud_domain: "cloud.example.com"
nextcloud_email: "admin@example.com"

# Exécuter avec le vault
ansible-playbook -i inventory.ini deploy-nextcloud.yml -e @secrets.yml --ask-vault-pass
```

## 🧪 Test en Local

Pour tester en local avant le déploiement :

```ini
[nextcloud_servers]
localhost ansible_connection=local
```

```bash
sudo ansible-playbook -i inventory.ini deploy-nextcloud.yml
```

## ⚠️ Dépannage

### Erreur : "Host key verification failed"

```bash
# Ajouter la clé SSH du serveur
ssh-keyscan -H cloud.example.com >> ~/.ssh/known_hosts
```

### Erreur : "Permission denied"

```bash
# Vérifier l'accès SSH
ssh -i ~/.ssh/id_rsa debian@cloud.example.com

# Vérifier les permissions de la clé
chmod 600 ~/.ssh/id_rsa
```

### Erreur : "Failed to connect to the host"

```bash
# Tester la connexion Ansible
ansible -i inventory.ini nextcloud_servers -m ping -vvv

# Vérifier la configuration SSH
ansible -i inventory.ini nextcloud_servers -m setup
```

## 📚 Ressources

- [Documentation Ansible](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Documentation Nextcloud](https://docs.nextcloud.com/)

## 📞 Support

Si vous rencontrez des problèmes :
1. Vérifiez les logs avec `-vvv`
2. Consultez `~/nextcloud-info.txt` sur le serveur cible
3. Ouvrez une issue sur GitHub avec les logs pertinents
