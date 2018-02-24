#!/usr/bin/env bash

command -v docker >/dev/null 2>&1 || {
    echo "Docker not found. Installing..." >&2;
    # Update apt-get
    apt-get update

    # Lets remove any old Docker installations.
    apt-get remove -y docker docker-engine docker-ce docker.io

    # Install Docker dependencies & git.
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        git

    # Adding Docker’s official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Verify fingerprint
    apt-key fingerprint 0EBFCD88

    # Adding repository
    add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"

    # Update apt-get
    apt-get update

    # Install Docker CE
    apt-get install -y docker-ce
}

command -v docker-compose >/dev/null 2>&1 || {
    echo "docker-compose not found. Installing..." >&2;
    # get latest docker compose released tag
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

    # Install docker-compose
    sh -c "curl -L https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
    chmod +x /usr/local/bin/docker-compose

    # Show docker-compose version
    docker-compose --version
    }

command -v nginx >/dev/null 2>&1 || {
    # Install Nginx
    apt-get install -y nginx

    # Adding reverse proxy generic settings
    /bin/cat <<EOM > /etc/nginx/reverse-proxy.conf
proxy_pass_header Server;
proxy_set_header Host \$http_host;
proxy_redirect off;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Scheme \$scheme;
proxy_set_header X-Forwarded-Host \$host;
proxy_set_header X-Forwarded-Proto \$scheme;
proxy_connect_timeout 3600;
proxy_read_timeout 3600;
proxy_set_header Connection "";
proxy_http_version 1.1;
EOM

    #creating certificates directory
    mkdir -p /etc/nginx/certificates/

}

# creating certbot dir for domain
mkdir -p /var/www/${1}

# creating certbot dir for domain
mkdir -p /etc/nginx/certificates/${1}

# Adding domain to nginx
/bin/cat <<EOM > /etc/nginx/sites-enabled/${1}
server {
    listen 80;
    server_name $1;

    location /.well-known {
            alias /var/www/$1/.well-known;
    }
}
EOM

# Reloading Nnginx
service nginx restart

#certbot setup
command -v certbot >/dev/null 2>&1 || {
    # Adding certbot repo
    add-apt-repository ppa:certbot/certbot -y

    # Update apt-get
    apt-get update

    # Install certbot
    apt-get install -y certbot
}

# Adding SSL
rm /etc/nginx/certificates/${1}/cert.pem >/dev/null 2>&1
rm /etc/nginx/certificates/${1}/key.pem >/dev/null 2>&1
rm -rf /etc/letsencrypt/live/${1} >/dev/null 2>&1
rm -rf /etc/letsencrypt/renewal/${1}.conf >/dev/null 2>&1
rm -rf /etc/letsencrypt/archive/${1} >/dev/null 2>&1

certbot certonly --webroot -w /var/www/${1}/ -d ${1} --email ${3} --agree-tos --no-eff-email
ln  -s /etc/letsencrypt/live/${1}/fullchain.pem /etc/nginx/certificates/${1}/cert.pem
ln -s /etc/letsencrypt/live/${1}/privkey.pem /etc/nginx/certificates/${1}/key.pem

# UPDATING domain configs to nginx
/bin/cat <<EOM > /etc/nginx/sites-enabled/${1}
server {
    listen 80;
    server_name $1;

    location /.well-known {
            alias /var/www/$1/.well-known;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
        listen 443 ssl;

        server_name $1;

        ssl on;
        ssl_certificate /etc/nginx/certificates/$1/cert.pem;
        ssl_certificate_key /etc/nginx/certificates/$1/key.pem;

    location /adminer.php {
        include /etc/nginx/reverse-proxy.conf;
        proxy_pass http://localhost:$2/adminer.php;
    }

    location / {
        include /etc/nginx/reverse-proxy.conf;

        if (\$request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' \$http_origin always;
                add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE' always;
                add_header 'Access-Control-Allow-Credentials' 'true' always;
                add_header 'Access-Control-Allow-Headers' 'Origin,Content-Type,Accept,Authorization' always;
                add_header Content-Length 0;
                add_header Content-Type text/plain;
                return 204;
        }
        add_header 'Access-Control-Allow-Origin' \$http_origin always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        proxy_pass http://localhost:$2/;
    }
}
EOM

# Reloading Nnginx
service nginx restart

echo "Configured $1 to post: $2"