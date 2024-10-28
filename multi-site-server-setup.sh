#!/bin/bash

# Usage Instructions:
# This script sets up a multi-site hosting server on an Ubuntu machine.
# It will install and configure NGINX, PostgreSQL, MySQL, PHP, Gunicorn, and SSL using Let's Encrypt for multiple domains.
# It supports running sites with different software stacks such as WordPress (PHP) and Django (Python).
# Ensure you run this script as the root user or with sudo privileges.
# Update the domains list and user information as needed before running the script.

# Load Domains and User Information from External File
CONFIG_FILE="./config_file.sh"
if [[ ! -f $CONFIG_FILE ]]; then
  echo "Error: Configuration file $CONFIG_FILE not found!"
  exit 1
fi
source $CONFIG_FILE # This file should define variables: domains, NEW_USER, USER_PASSWORD, HOSTNAME, INSTALL_REDIS, SSL_EMAIL, INSTALL_FAIL2BAN, INSTALL_CLAMAV, ENABLE_BACKUPS, USE_DO_SPACES, DO_SPACES_ACCESS_KEY, DO_SPACES_SECRET_KEY, DO_SPACES_BUCKET_NAME, DO_SPACES_REGION, ENABLE_EMAIL_NOTIFICATIONS

# Update and Upgrade the System
sudo apt-get update -y && sudo apt-get upgrade -y

# Set Hostname
if [[ -z "$HOSTNAME" ]]; then
  HOSTNAME="multisite-server"
fi
sudo hostnamectl set-hostname $HOSTNAME

# Install Optional Tools
if [[ "$INSTALL_FAIL2BAN" == "true" ]]; then
  sudo apt-get install -y fail2ban
  sudo systemctl enable fail2ban
  sudo systemctl start fail2ban
fi

# Install AWS CLI for DigitalOcean Spaces if enabled
if [[ "$USE_DO_SPACES" == "true" ]]; then
  sudo apt-get install -y awscli
  aws configure set aws_access_key_id $DO_SPACES_ACCESS_KEY
  aws configure set aws_secret_access_key $DO_SPACES_SECRET_KEY
  aws configure set default.region $DO_SPACES_REGION
  aws configure set default.output json
fi

# Install Necessary Tools
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common ufw nginx postgresql postgresql-contrib mysql-server python3 python3-pip certbot python3-certbot-nginx php php-fpm php-mysql php-xml php-mbstring php-curl php-gd php-zip

# Ensure pip and virtualenv are up-to-date
sudo -H pip3 install --upgrade pip
sudo -H pip3 install --upgrade virtualenv

# Optional: Install Redis if enabled
if [[ "$INSTALL_REDIS" == "true" ]]; then
  sudo apt-get install -y redis-server
  sudo systemctl enable redis-server
  sudo systemctl start redis-server
fi

# Create a New User and Set Password
if id "$NEW_USER" &>/dev/null; then
  echo "User $NEW_USER already exists. Skipping user creation."
else
  sudo adduser --disabled-password --gecos "" $NEW_USER
  echo "$NEW_USER:$USER_PASSWORD" | sudo chpasswd
fi

# Add User to Sudoers Without Requiring Password
if [[ ! -f /etc/sudoers.d/$NEW_USER ]]; then
  echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$NEW_USER
fi

# Copy SSH Keys from Root to New User
if [[ -d /root/.ssh && -f /root/.ssh/authorized_keys ]]; then
  sudo mkdir -p /home/$NEW_USER/.ssh
  sudo cp /root/.ssh/authorized_keys /home/$NEW_USER/.ssh/
  sudo chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
  sudo chmod 700 /home/$NEW_USER/.ssh
  sudo chmod 600 /home/$NEW_USER/.ssh/authorized_keys
else
  echo "Warning: No SSH keys found in /root/.ssh to copy."
fi

# Install Optional ClamAV for Malware Scanning
if [[ "$INSTALL_CLAMAV" == "true" ]]; then
  sudo apt-get install -y clamav
  sudo freshclam
  sudo systemctl enable clamav-freshclam
  sudo systemctl start clamav-freshclam
fi

# Set Up Firewall (UFW)
if ! sudo ufw status | grep -q "Status: active"; then
  sudo ufw allow OpenSSH
  sudo ufw allow 'Nginx Full'
  echo "y" | sudo ufw enable
fi

# Harden SSH Configuration
if grep -q "#Port 22" /etc/ssh/sshd_config; then
  sudo sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
fi
if grep -q "#PermitRootLogin yes" /etc/ssh/sshd_config; then
  sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
fi
if grep -q "#PasswordAuthentication yes" /etc/ssh/sshd_config; then
  sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
fi
sudo systemctl reload sshd

# Set Up NGINX Configuration for Multi-Site
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

for domain_entry in "${domains[@]}"
do
  domain="$(echo $domain_entry | cut -d':' -f1)"
  domain_type="$(echo $domain_entry | cut -d':' -f2)"
  db_type="$(echo $domain_entry | cut -d':' -f3)"
  db_user="$(echo $domain_entry | cut -d':' -f4)"
  db_password="$(echo $domain_entry | cut -d':' -f5)"
  SITE_ROOT="/var/www/$domain/host"

  # Create Website Root Directory
  sudo mkdir -p $SITE_ROOT/{html,static,media,venv,logs}
  sudo chown -R $NEW_USER:$NEW_USER $SITE_ROOT

  # Create NGINX Site Configuration based on domain type
  if [[ "$domain_type" == "php" ]]; then
    # PHP Configuration (e.g., WordPress)
    cat <<EOF | sudo tee /etc/nginx/sites-available/$domain
server {
    listen 80;
    server_name $domain;

    root $SITE_ROOT;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
  elif [[ "$domain_type" == "python" ]]; then
    # Django Configuration
    cat <<EOF | sudo tee /etc/nginx/sites-available/$domain
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://127.0.0.1:$((8000 + RANDOM % 1000)); # Port where gunicorn is running
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        alias /var/www/$domain/host/static/;
    }

    location /media/ {
        alias /var/www/$domain/host/media/;
    }
}
EOF
  elif [[ "$domain_type" == "html" ]]; then
    # Static HTML Configuration
    cat <<EOF | sudo tee /etc/nginx/sites-available/$domain
server {
    listen 80;
    server_name $domain;

    root $SITE_ROOT;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
  fi

  # Enable Site and Reload NGINX
  if [[ ! -f /etc/nginx/sites-enabled/$domain ]]; then
    sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
  fi

done

sudo nginx -t && sudo systemctl reload nginx

# Set Up MySQL for WordPress Sites
sudo systemctl start mysql
sudo systemctl enable mysql
for domain_entry in "${domains[@]}"
do
  domain="$(echo $domain_entry | cut -d':' -f1)"
  domain_type="$(echo $domain_entry | cut -d':' -f2)"
  db_user="$(echo $domain_entry | cut -d':' -f4)"
  db_password="$(echo $domain_entry | cut -d':' -f5)"
  if [[ "$domain_type" == "php" ]]; then
    DB_NAME="${domain//./_}_wp_db"
    if ! sudo mysql -u root -e "USE $DB_NAME;" &>/dev/null; then
      sudo mysql -u root -e "CREATE DATABASE $DB_NAME;"
      sudo mysql -u root -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';"
      sudo mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$db_user'@'localhost';"
      sudo mysql -u root -e "FLUSH PRIVILEGES;"
    else
      echo "MySQL database $DB_NAME already exists. Skipping creation."
    fi
  fi
done

# Set Up PostgreSQL Databases and Users for Django Sites
sudo systemctl start postgresql
sudo systemctl enable postgresql
for domain_entry in "${domains[@]}"
do
  domain="$(echo $domain_entry | cut -d':' -f1)"
  domain_type="$(echo $domain_entry | cut -d':' -f2)"
  db_user="$(echo $domain_entry | cut -d':' -f4)"
  db_password="$(echo $domain_entry | cut -d':' -f5)"
  if [[ "$domain_type" == "python" ]]; then
    DB_NAME="${domain//./_}_pg_db"
    if ! sudo -u postgres psql -c "\l" | grep -q $DB_NAME; then
      sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
      sudo -u postgres psql -c "CREATE USER $db_user WITH PASSWORD '$db_password';"
      sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $db_user;"
    else
      echo "PostgreSQL database $DB_NAME already exists. Skipping creation."
    fi
  fi
done

# Set Up Gunicorn for Django Sites
for domain_entry in "${domains[@]}"
do
  domain="$(echo $domain_entry | cut -d':' -f1)"
  domain_type="$(echo $domain_entry | cut -d':' -f2)"
  if [[ "$domain_type" == "python" ]]; then
    SITE_ROOT="/var/www/$domain"
    if [[ ! -d "$SITE_ROOT/venv" ]]; then
      sudo -u $NEW_USER bash -c "cd $SITE_ROOT && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt && deactivate"
    fi
    GUNICORN_SERVICE_FILE="/etc/systemd/system/gunicorn_$domain.service"
    if [[ ! -f $GUNICORN_SERVICE_FILE ]]; then
      cat <<EOF | sudo tee $GUNICORN_SERVICE_FILE
[Unit]
Description=gunicorn daemon for $domain
After=network.target

[Service]
User=$NEW_USER
Group=www-data
WorkingDirectory=$SITE_ROOT
ExecStart=$SITE_ROOT/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 projectname.wsgi:application

[Install]
WantedBy=multi-user.target
EOF
      sudo systemctl start gunicorn_$domain
      sudo systemctl enable gunicorn_$domain
    else
      echo "Gunicorn service for $domain already exists. Skipping creation."
    fi
  fi
done

# Obtain SSL Certificates for Each Domain Using Let's Encrypt
for domain_entry in "${domains[@]}"
do
  domain="$(echo $domain_entry | cut -d':' -f1)"
  if ! sudo certbot certificates | grep -q $domain; then
    sudo certbot --nginx -d $domain --non-interactive --agree-tos -m $SSL_EMAIL
  else
    echo "SSL certificate for $domain already exists. Skipping."
  fi
done

# Set Up Certbot Auto Renewal
sudo systemctl enable certbot.timer

# Set Up Automatic Backups
if [[ "$ENABLE_BACKUPS" == "true" ]]; then
  sudo mkdir -p $BACKUP_DIR
 
