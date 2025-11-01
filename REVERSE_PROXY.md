# Configuration Reverse Proxy pour Nextcloud

Ce guide explique comment configurer différents reverse proxies (Nginx, Caddy, Traefik, HAProxy) pour accéder à Nextcloud via HTTPS avec Let's Encrypt.

## 📋 Prérequis

1. Nextcloud installé avec l'option `--reverse-proxy`
2. Nom de domaine pointant vers votre serveur
3. Ports 80 et 443 ouverts dans le pare-feu

## ⚙️ Installation de Nextcloud en Mode Reverse Proxy

```bash
curl -fsSL https://raw.githubusercontent.com/tiagomatiastm-prog/nextcloud-installer/master/install-nextcloud.sh | \
  sudo bash -s -- \
    --domain cloud.example.com \
    --email admin@example.com \
    --reverse-proxy \
    --install-office \
    --install-talk
```

Avec cette configuration :
- Nextcloud écoute sur `127.0.0.1:80`
- Le reverse proxy gère HTTPS et redirige vers Nextcloud
- Collabora (si installé) écoute sur `127.0.0.1:9980`

---

## 🔷 Option 1 : Nginx

### Installation de Nginx

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

### Configuration Nextcloud

Créez `/etc/nginx/sites-available/nextcloud` :

```nginx
upstream nextcloud {
    server 127.0.0.1:80;
}

upstream collabora {
    server 127.0.0.1:9980;
}

# Redirection HTTP vers HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name cloud.example.com;

    # Let's Encrypt challenge
    location ^~ /.well-known/acme-challenge {
        root /var/www/html;
        allow all;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Configuration HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name cloud.example.com;

    # Certificats SSL (seront générés par certbot)
    ssl_certificate /etc/letsencrypt/live/cloud.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cloud.example.com/privkey.pem;

    # Configuration SSL moderne
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    # HSTS
    add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload" always;

    # Limites de taille
    client_max_body_size 10G;
    client_body_buffer_size 400M;

    # Timeouts
    proxy_connect_timeout 3600;
    proxy_send_timeout 3600;
    proxy_read_timeout 3600;
    send_timeout 3600;

    # Headers pour reverse proxy
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;

    # Nextcloud
    location / {
        proxy_pass http://nextcloud;
        proxy_redirect off;
    }

    # WebDAV
    location ~ ^/remote/(.*) {
        proxy_pass http://nextcloud;
        proxy_redirect off;
    }

    # Collabora Online (si installé)
    location ^~ /browser {
        proxy_pass http://collabora;
        proxy_redirect off;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location ^~ /hosting/discovery {
        proxy_pass http://collabora;
        proxy_redirect off;
    }

    location ^~ /cool/ {
        proxy_pass http://collabora;
        proxy_redirect off;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Activation et Obtention du Certificat

```bash
# Créer le répertoire pour Let's Encrypt
sudo mkdir -p /var/www/html/.well-known/acme-challenge

# Activer la configuration
sudo ln -s /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/

# Tester la configuration
sudo nginx -t

# Redémarrer Nginx
sudo systemctl restart nginx

# Obtenir le certificat Let's Encrypt
sudo certbot --nginx -d cloud.example.com

# Renouvellement automatique (déjà configuré par certbot)
sudo systemctl status certbot.timer
```

---

## 🟢 Option 2 : Caddy (Plus Simple)

### Installation de Caddy

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

### Configuration Nextcloud

Éditez `/etc/caddy/Caddyfile` :

```caddy
cloud.example.com {
    # Caddy gère automatiquement HTTPS avec Let's Encrypt

    # Limites de taille
    request_body {
        max_size 10GB
    }

    # Headers pour reverse proxy
    header {
        Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"
    }

    # Nextcloud
    reverse_proxy 127.0.0.1:80 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
    }

    # Collabora Online (si installé)
    handle /browser* {
        reverse_proxy 127.0.0.1:9980 {
            transport http {
                versions h2c 1.1
            }
        }
    }

    handle /hosting/discovery {
        reverse_proxy 127.0.0.1:9980
    }

    handle /cool/* {
        reverse_proxy 127.0.0.1:9980 {
            transport http {
                versions h2c 1.1
            }
        }
    }
}
```

### Activation

```bash
# Tester la configuration
sudo caddy validate --config /etc/caddy/Caddyfile

# Redémarrer Caddy
sudo systemctl restart caddy

# Vérifier le statut
sudo systemctl status caddy
```

**Caddy gère automatiquement** :
- Obtention du certificat Let's Encrypt
- Renouvellement automatique
- Redirection HTTP vers HTTPS

---

## 🟣 Option 3 : Traefik

### Installation de Traefik

```bash
# Créer la structure
sudo mkdir -p /etc/traefik/{dynamic,certs}

# Télécharger Traefik
wget https://github.com/traefik/traefik/releases/download/v2.11.0/traefik_v2.11.0_linux_amd64.tar.gz
tar -xzf traefik_v2.11.0_linux_amd64.tar.gz
sudo mv traefik /usr/local/bin/
sudo chmod +x /usr/local/bin/traefik
```

### Configuration Statique

Créez `/etc/traefik/traefik.yml` :

```yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https

  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
      storage: /etc/traefik/certs/acme.json
      httpChallenge:
        entryPoint: web

providers:
  file:
    directory: /etc/traefik/dynamic
    watch: true

api:
  dashboard: false
```

### Configuration Dynamique

Créez `/etc/traefik/dynamic/nextcloud.yml` :

```yaml
http:
  routers:
    nextcloud:
      rule: "Host(`cloud.example.com`)"
      entryPoints:
        - websecure
      service: nextcloud
      tls:
        certResolver: letsencrypt

    collabora:
      rule: "Host(`cloud.example.com`) && (PathPrefix(`/browser`) || PathPrefix(`/hosting`) || PathPrefix(`/cool`))"
      entryPoints:
        - websecure
      service: collabora
      tls:
        certResolver: letsencrypt

  services:
    nextcloud:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:80"

    collabora:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:9980"

  middlewares:
    nextcloud-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        stsSeconds: 15768000
        stsIncludeSubdomains: true
        stsPreload: true
```

### Service Systemd

Créez `/etc/systemd/system/traefik.service` :

```ini
[Unit]
Description=Traefik Reverse Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
```

### Activation

```bash
# Créer le fichier ACME
sudo touch /etc/traefik/certs/acme.json
sudo chmod 600 /etc/traefik/certs/acme.json

# Activer et démarrer
sudo systemctl daemon-reload
sudo systemctl enable traefik
sudo systemctl start traefik
sudo systemctl status traefik
```

---

## 🔶 Option 4 : HAProxy

### Installation de HAProxy

```bash
sudo apt update
sudo apt install -y haproxy certbot
```

### Configuration HAProxy

Éditez `/etc/haproxy/haproxy.cfg` :

```haproxy
global
    log /dev/log local0
    log /dev/log local1 notice
    maxconn 4096
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2

defaults
    log global
    mode http
    option httplog
    option dontlognull
    timeout connect 5000
    timeout client 3600000
    timeout server 3600000

frontend http_front
    bind *:80
    acl letsencrypt_challenge path_beg /.well-known/acme-challenge/
    use_backend letsencrypt if letsencrypt_challenge
    default_backend redirect_https

backend redirect_https
    redirect scheme https code 301

frontend https_front
    bind *:443 ssl crt /etc/haproxy/certs/cloud.example.com.pem

    # Headers
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-Host %[req.hdr(Host)]

    # HSTS
    http-response set-header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"

    # Routing
    acl is_collabora path_beg /browser /hosting /cool
    use_backend collabora if is_collabora
    default_backend nextcloud

backend nextcloud
    server nextcloud1 127.0.0.1:80 check

backend collabora
    server collabora1 127.0.0.1:9980 check

backend letsencrypt
    server letsencrypt 127.0.0.1:8888
```

### Obtention du Certificat

```bash
# Créer le répertoire des certificats
sudo mkdir -p /etc/haproxy/certs

# Obtenir le certificat
sudo certbot certonly --standalone -d cloud.example.com \
    --non-interactive --agree-tos --email admin@example.com \
    --http-01-port=8888

# Combiner les certificats pour HAProxy
sudo cat /etc/letsencrypt/live/cloud.example.com/fullchain.pem \
    /etc/letsencrypt/live/cloud.example.com/privkey.pem | \
    sudo tee /etc/haproxy/certs/cloud.example.com.pem

# Renouvellement automatique
sudo crontab -e
# Ajouter:
# 0 0 * * * certbot renew --quiet --post-hook "cat /etc/letsencrypt/live/cloud.example.com/*.pem > /etc/haproxy/certs/cloud.example.com.pem && systemctl reload haproxy"
```

### Activation

```bash
# Tester la configuration
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

# Redémarrer HAProxy
sudo systemctl restart haproxy
sudo systemctl status haproxy
```

---

## 🔐 Configuration du Pare-feu

### UFW (Ubuntu/Debian)

```bash
# Autoriser HTTP et HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Si Nextcloud Talk installé
sudo ufw allow 3478/udp
sudo ufw allow 3478/tcp
sudo ufw allow 5349/tcp

# Activer le pare-feu
sudo ufw enable
sudo ufw status
```

### iptables

```bash
# HTTP et HTTPS
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Talk (si installé)
sudo iptables -A INPUT -p udp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5349 -j ACCEPT

# Sauvegarder
sudo netfilter-persistent save
```

---

## ✅ Vérification

### Test de Connectivité

```bash
# Vérifier HTTP redirige vers HTTPS
curl -I http://cloud.example.com

# Vérifier HTTPS fonctionne
curl -I https://cloud.example.com

# Vérifier le certificat SSL
echo | openssl s_client -connect cloud.example.com:443 -servername cloud.example.com
```

### Test de Collabora (si installé)

```bash
# Vérifier l'accès à Collabora
curl -I https://cloud.example.com/browser/dist/bundle.js
```

### Logs

```bash
# Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Caddy
sudo journalctl -u caddy -f

# Traefik
sudo journalctl -u traefik -f

# HAProxy
sudo tail -f /var/log/haproxy.log
```

---

## 🆘 Dépannage

### Problème : "Trusted domain" erreur

```bash
# Ajouter le domaine aux trusted domains
sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 0 --value="cloud.example.com"
```

### Problème : Boucle de redirection

```bash
# Vérifier la configuration reverse proxy dans Nextcloud
sudo -u www-data php /var/www/nextcloud/occ config:system:get overwriteprotocol
# Doit retourner: https

sudo -u www-data php /var/www/nextcloud/occ config:system:get overwritehost
# Doit retourner: cloud.example.com
```

### Problème : Upload de fichiers échoue

Vérifiez les limites dans le reverse proxy :
- **Nginx** : `client_max_body_size`
- **Caddy** : `request_body max_size`
- **Traefik** : Headers middleware
- **HAProxy** : Timeouts

---

## 📚 Ressources

- [Nextcloud Reverse Proxy Documentation](https://docs.nextcloud.com/server/latest/admin_manual/installation/harden_server.html)
- [Nginx SSL Configuration](https://ssl-config.mozilla.org/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [HAProxy Documentation](https://www.haproxy.org/documentation.html)
