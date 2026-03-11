#!/bin/bash

# Stop script on error
set -e

# Drupal on WSL script
echo -e "\n🚀 Drupal Development Environment for Ubuntu (PHP / Nginx / MariaDB)\n"

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# Update and upgrade packages
echo -e "${GREEN}Updating packages...${NC}"
sudo apt update && sudo apt list --upgradable && sudo apt upgrade -y

# Install Nala
echo -e "\n${GREEN}Installing Nala...${NC}"
sudo apt install nala software-properties-common -y

# Add PHP PPA
echo -e "\n${GREEN}Adding PHP PPA...${NC}"
sudo add-apt-repository ppa:ondrej/php -y

# Update using Nala
echo -e "\n${GREEN}Updating with Nala...${NC}"
sudo nala update && sudo nala list --upgradable && sudo nala upgrade -y

# List of packages to install
PACKAGES=(
  nginx
  php8.4-fpm
  php8.4-mysql
  mariadb-server
  php8.4-apcu
  php8.4-uploadprogress
  ffmpeg
  php8.4-ldap
  php8.4-cli
  php8.4-gd
  php8.4-zip
  php8.4-xml
  php8.4-mbstring
  php8.4-curl
  php8.4-bcmath
  php8.4-opcache
  php8.4-intl
  php8.4-imagick
  libavif-bin
  libmagickcore-6.q16-6-extra
  build-essential
  cmake
  pkg-config
  acl
)

# Install all packages at once using Nala (--no-install-recommends prevents Apache2 from sneaking in)
echo -e "\n${GREEN}Installing packages...${NC}"
sudo nala install -y --no-install-recommends "${PACKAGES[@]}"

# Ensure Apache2 is completely removed if it was previously installed
echo -e "\n${GREEN}Ensuring Apache2 is not present...${NC}"
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl disable apache2 2>/dev/null || true
sudo apt-get purge -y 'apache2*' 'libapache2*' 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true

# Set PHP as default
echo -e "\n${GREEN}Setting PHP 8.4 as default...${NC}"
sudo update-alternatives --set php /usr/bin/php8.4
sudo update-alternatives --set phar /usr/bin/phar8.4
sudo update-alternatives --set phar.phar /usr/bin/phar.phar8.4

# Proper Composer installation
echo -e "\n${GREEN}Installing Composer...${NC}"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === file_get_contents('https://composer.github.io/installer.sig')) { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); exit(1); }"
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"



# Install FastFetch
echo -e "\n${GREEN}Installing FastFetch...${NC}"
if [ -d "/tmp/fastfetch" ]; then rm -rf /tmp/fastfetch; fi
git clone -q https://github.com/fastfetch-cli/fastfetch.git /tmp/fastfetch
cmake -S /tmp/fastfetch -B /tmp/fastfetch/build -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build /tmp/fastfetch/build --parallel >/dev/null
sudo cp /tmp/fastfetch/build/fastfetch /usr/local/bin/fastfetch

# Removido comando A2ENMOD pois o Nginx usará PHP-FPM nativo

# Set permissions for the current user on /var/www and Nginx vhosts
echo -e "\n${GREEN}Setting directory permissions for current user...${NC}"
CURRENT_USER=$(whoami)
sudo chown -R "$CURRENT_USER":www-data /var/www
sudo chmod -R 2775 /var/www
sudo chown -R "$CURRENT_USER":www-data /etc/nginx/sites-available
sudo chown -R "$CURRENT_USER":www-data /etc/nginx/sites-enabled

# Adjust PHP settings
echo -e "\n${GREEN}Adjusting PHP settings...${NC}"
PHP_INI="/etc/php/8.4/fpm/php.ini"
sudo sed -i 's/memory_limit = .*/memory_limit = 2048M/' "$PHP_INI"
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 512M/' "$PHP_INI"
sudo sed -i 's/post_max_size = .*/post_max_size = 2048M/' "$PHP_INI"
sudo sed -i 's/max_execution_time = .*/max_execution_time = 180/' "$PHP_INI"
sudo sed -i 's/max_input_time = .*/max_input_time = 180/' "$PHP_INI"

# Configure APCu
echo -e "\n${GREEN}Configuring APCu...${NC}"
DETECTED_PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
APCU_INI="/etc/php/${DETECTED_PHP_VERSION}/mods-available/apcu.ini"
echo "extension=apcu.so" | sudo tee "$APCU_INI" > /dev/null
echo "apc.shm_size=128M" | sudo tee -a "$APCU_INI" > /dev/null
sudo phpenmod -v "${DETECTED_PHP_VERSION}" apcu

# Restart Nginx and PHP-FPM
sudo systemctl restart nginx php8.4-fpm

# Check if services are running and display status
echo -e "\n${GREEN}Checking installation status...${NC}"

check_service() {
  if systemctl is-active --quiet "$1"; then
    echo -e "${GREEN}✓ $1 is running${NC}"
    return 0
  else
    echo -e "${RED}✗ $1 failed to start${NC}"
    return 1
  fi
}

SERVICES=(nginx php8.4-fpm mariadb)
FAILED=0

for SERVICE in "${SERVICES[@]}"; do
  check_service "$SERVICE" || ((FAILED++))
done

# Check PHP installation
if command -v php &> /dev/null; then
  INSTALLED_PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2)
  echo -e "${GREEN}✓ PHP $INSTALLED_PHP_VERSION is installed${NC}"

  # Check AVIF Support
  if php -i | grep -q "AVIF Support => enabled"; then
      echo -e "${GREEN}✓ PHP GD AVIF Support enabled${NC}"
  else
      echo -e "${YELLOW}⚠ PHP GD AVIF Support NOT found (check libavif)${NC}"
  fi
else
  echo -e "${RED}✗ PHP installation failed${NC}"
  ((FAILED++))
fi

# Check Composer installation
if command -v composer &> /dev/null; then
  COMPOSER_VERSION=$(composer --version | cut -d' ' -f2)
  echo -e "${GREEN}✓ Composer $COMPOSER_VERSION is installed${NC}"
else
  echo -e "${RED}✗ Composer installation failed${NC}"
  ((FAILED++))
fi

# Install Zsh and Oh My Zsh
echo -e "\n${GREEN}Installing Zsh and Oh My Zsh...${NC}"
sudo nala install -y zsh curl git

# Backup existing .zshrc
if [ -f ~/.zshrc ]; then
    echo -e "${YELLOW}Backing up existing .zshrc to .zshrc.backup...${NC}"
    cp ~/.zshrc ~/.zshrc.backup
fi

# Install Oh My Zsh (unattended)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Make Zsh the default shell
chsh -s "$(which zsh)"

# Clone plugin repositories
mkdir -p "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
# Only clone if not exists to avoid errors on re-run
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
fi
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
fi
if [ ! -d "$HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all
fi
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-z" ]; then
    git clone https://github.com/agkozak/zsh-z "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-z"
fi

# Configure Zsh
echo -e "\n${GREEN}Configuring Zsh...${NC}"
{
  echo "# Oh My Zsh configuration"
  echo "export ZSH=\"\$HOME/.oh-my-zsh\""
  echo "ZSH_THEME=\"af-magic\""
  echo ""
  echo "# Plugins"
  echo "plugins=("
  echo "  git"
  echo "  ssh-agent"
  echo "  zsh-autosuggestions"
  echo "  fzf"
  echo "  z"
  echo "  zsh-syntax-highlighting"
  echo ")"
  echo ""
  echo "# NVM Setup"
  echo "export NVM_DIR=\"\\\$HOME/.nvm\""
  echo "[ -s \"\\\$NVM_DIR/nvm.sh\" ] && \\. \"\\\$NVM_DIR/nvm.sh\"  # This loads nvm"
  echo "[ -s \"\\\$NVM_DIR/bash_completion\" ] && \\. \"\\\$NVM_DIR/bash_completion\"  # This loads nvm bash_completion"
  echo ""
  echo "# Starship prompt"
  echo "eval \"\$(starship init zsh)\""
  echo ""
  echo "# Function that executes Drush regardless of the directory."
  echo "drush() {"
  echo "  local current_dir=\$(pwd)"
  echo "  local project_root=\"\""
  echo ""
  echo "  while [[ \"\$current_dir\" != \"/\" ]]; do"
  echo "    if [[ -f \"\$current_dir/vendor/drush/drush/drush\" ]]; then"
  echo "      project_root=\"\$current_dir\""
  echo "      break"
  echo "    fi"
  echo "    current_dir=\$(dirname \"\$current_dir\")"
  echo "  done"
  echo ""
  echo "  if [[ -n \"\$project_root\" ]]; then"
  echo "    \"\$project_root/vendor/drush/drush/drush\" \"\$@\""
  echo "  else"
  echo "    echo \"Drush not found! Make sure you are inside a Drupal project.\""
  echo "    return 1"
  echo "  fi"
  echo "}"
  echo ""
  echo "# Function to fix permissions on Drupal files directory"
  echo "fix-perms() {"
  echo "  local current_user=\$(whoami)"
  echo "  local target_dir=\"\${1:-\"web/sites/default/files\"}\""
  echo ""
  echo "  if [ ! -d \"\$target_dir\" ]; then"
  echo "    if [ -d \"sites/default/files\" ]; then"
  echo "      target_dir=\"sites/default/files\""
  echo "    fi"
  echo "  fi"
  echo ""
  echo "  echo \"Fixing permissions for \$current_user:www-data on \$target_dir...\""
  echo "  sudo chown -R \$current_user:www-data \$target_dir"
  echo "  sudo chmod -R 2775 \$target_dir"
  echo "  sudo setfacl -R -m u:\${current_user}:rwx \$target_dir"
  echo "  sudo setfacl -R -m g:www-data:rwx \$target_dir"
  echo "  sudo setfacl -R -d -m u:\${current_user}:rwx \$target_dir"
  echo "  sudo setfacl -R -d -m g:www-data:rwx \$target_dir"
  echo "  echo \"Permissions fixed successfully!\""
  echo "}"
  echo ""
  echo "# Function to create an Nginx vhost"
  echo "create-vhost() {"
  echo "  if [ -z \"\$1\" ] || [ -z \"\$2\" ]; then"
  echo "    echo \"Usage: create-vhost <domain.local> <absolute_path_to_root>\""
  echo "    echo \"Example: create-vhost mysite.local /var/www/mysite/web\""
  echo "    return 1"
  echo "  fi"
  echo "  local domain=\$1"
  echo "  local root_dir=\$2"
  echo "  local vhost_file=\"/etc/nginx/sites-available/\$domain\""
  echo ""
  echo "  if [ ! -d \"\$root_dir\" ]; then"
  echo "    echo \"Error: The directory \$root_dir does not exist.\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  echo \"Creating Nginx vhost for \$domain...\""
  echo "  cat > \"\$vhost_file\" <<VHOSTEOF"
  echo "server {"
  echo "    listen 80;"
  echo "    listen [::]:80;"
  echo "    server_name \$domain;"
  echo "    root \$root_dir;"
  echo ""
  echo "    index index.php index.html;"
  echo ""
  echo "    location / {"
  echo '        try_files \$uri /index.php?\$query_string;'
  echo "    }"
  echo ""
  echo "    location @rewrite {"
  echo '        rewrite ^/(.*)$ /index.php?q=\$1;'
  echo "    }"
  echo ""
  echo "    location ~ '\.php\$|^/update.php' {"
  echo '        fastcgi_split_path_info ^(.+?\.php)(|/.*)$;'
  echo "        include fastcgi_params;"
  echo "        include snippets/fastcgi-php.conf;"
  echo '        fastcgi_param HTTP_PROXY \"\";'
  echo '        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;'
  echo '        fastcgi_param PATH_INFO \$fastcgi_path_info;'
  echo '        fastcgi_param QUERY_STRING \$query_string;'
  echo "        fastcgi_intercept_errors on;"
  echo "        fastcgi_pass unix:/run/php/php8.4-fpm.sock;"
  echo "    }"
  echo ""
  echo "    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {"
  echo '        try_files \$uri @rewrite;'
  echo "        expires max;"
  echo "        log_not_found off;"
  echo "    }"
  echo ""
  echo "    location ~ ^/sites/.*/files/styles/ {"
  echo '        try_files \$uri @rewrite;'
  echo "    }"
  echo ""
  echo "    location ~ ^(/[a-z\\-]+)?/system/files/ {"
  echo '        try_files \$uri /index.php?\$query_string;'
  echo "    }"
  echo ""
  echo "    location ~* \\.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|twig|tpl(\\.php)?|xtmpl)([a-z\\-]+)?\$ {"
  echo "        deny all;"
  echo "    }"
  echo "}"
  echo "VHOSTEOF"
  echo ""
  echo "  ln -s \"\$vhost_file\" \"/etc/nginx/sites-enabled/\" 2>/dev/null || true"
  echo "  sudo systemctl restart nginx"
  echo "  echo \"Vhost created and enabled: http://\$domain\""
  echo "  echo \"Make sure to add '\$domain' to your Windows hosts file.\""
  echo "}"
  echo ""
  echo "# Function to create a MySQL database and user"
  echo "create-db() {"
  echo "  if [ -z \"\$1\" ]; then"
  echo "    echo \"Usage: create-db <db_and_user_name>\""
  echo "    echo \"This creates a database and a user with identical names, and grants all privileges.\""
  echo "    return 1"
  echo "  fi"
  echo "  local name=\$1"
  echo "  echo \"Creating database: \$name\""
  echo "  sudo mysql -e \"CREATE DATABASE IF NOT EXISTS \\\`\$name\\\`;\""
  echo "  echo \"Creating user: \$name with password: \$name\""
  echo "  sudo mysql -e \"CREATE USER IF NOT EXISTS '\$name'@'localhost' IDENTIFIED BY '\$name';\""
  echo "  echo \"Granting privileges...\""
  echo "  sudo mysql -e \"GRANT ALL PRIVILEGES ON \\\`\$name\\\`.* TO '\$name'@'localhost';\""
  echo "  sudo mysql -e \"FLUSH PRIVILEGES;\""
  echo "  echo \"Database & User \$name created successfully!\""
  echo "}"
  echo ""
  echo "# Function to delete a MySQL database and user"
  echo "delete-db() {"
  echo "  if [ -z \"\$1\" ]; then"
  echo "    echo \"Usage: delete-db <db_and_user_name>\""
  echo "    return 1"
  echo "  fi"
  echo "  local name=\$1"
  echo "  read -p \"Are you sure you want to drop the database and user '\$name'? [y/N] \" confirm"
  echo "  if [[ \$confirm == [yY] || \$confirm == [yY][eE][sS] ]]; then"
  echo "    echo \"Dropping user: \$name...\""
  echo "    sudo mysql -e \"DROP USER IF EXISTS '\$name'@'localhost';\""
  echo "    echo \"Dropping database: \$name...\""
  echo "    sudo mysql -e \"DROP DATABASE IF EXISTS \\\`\$name\\\`;\""
  echo "    echo \"Database and user \$name removed successfully!\""
  echo "  else"
  echo "    echo \"Operation cancelled.\""
  echo "  fi"
  echo "}"
  echo ""
  echo "# Function to initialize Drupal required directories and settings"
  echo "init-drupal() {"
  echo "  local settings_dir=\"web/sites/default\""
  echo "  local settings_file=\"\$settings_dir/settings.php\""
  echo ""
  echo "  if [ ! -d \"\$settings_dir\" ]; then"
  echo "    echo \"Error: Directory '\$settings_dir' not found. Are you in the Drupal project root?\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  echo \"Creating 'files' and 'private_files' directories...\""
  echo "  mkdir -p \"\$settings_dir/files\""
  echo "  mkdir -p \"\$settings_dir/private_files\""
  echo ""
  echo "  if [ -f \"\$settings_file\" ]; then"
  echo "    echo \"Removing existing config_sync_directory definition(s)...\""
  echo "    sed -i '/\$settings\\['\\''config_sync_directory'\\''\\]/d' \"\$settings_file\""
  echo "    sed -i '/\$settings\\[\"config_sync_directory\"\\]/d' \"\$settings_file\""
  echo ""
  echo "    echo \"Appending new sync and private path settings...\""
  echo "    echo \"\" >> \"\$settings_file\""
  echo "    echo \"\\\$settings['config_sync_directory'] = '../config/sync';\" >> \"\$settings_file\""
  echo "    echo \"\\\$settings['file_private_path'] = \\\$app_root . '/sites/default/private_files';\" >> \"\$settings_file\""
  echo "    echo \"Settings updated successfully!\""
  echo "  else"
  echo "    echo \"Warning: '\$settings_file' does not exist yet. Run the Drupal installer first and run this command again or copy default.settings.php.\""
  echo "  fi"
  echo "  "
  echo "  echo \"Giving appropriate permissions...\""
  echo "  fix-perms"
  echo "}"
  echo ""

  echo "# Aliases"
  echo "alias sites=\"cd /var/www/\""
  echo "alias vhosts=\"cd /etc/nginx/sites-available/\""
  echo "alias update=\"sudo nala update && sudo nala list --upgradable && sudo nala upgrade -y\""
  echo "alias rnx=\"sudo service nginx restart\""
  echo "alias rmdb=\"sudo service mariadb restart\""
  echo "alias logs=\"tail -f /var/log/nginx/error.log\""
  echo "alias phplog=\"tail -f /var/log/php8.4-fpm.log\""
  echo "alias fp=\"fix-perms\""
  echo ""
  echo "alias ss1=\"npx sass scss/style.scss css/style.css -w --no-source-map\""
  echo "alias ss2=\"npx sass scss/ck5style.scss css/ck5style.css -w --no-source-map\""
  echo ""
} > ~/.zshrc

echo -e "\n${GREEN}Installing Starship...${NC}"
curl -sS https://starship.rs/install.sh | sh -s -- -y

echo -e "\n${GREEN}Installing NVM & Node.js LTS...${NC}"
export NVM_DIR="$HOME/.nvm"
curl -sL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'

echo -e "\n${GREEN}Configuring Starship with Catppuccin Powerline (Macchiato)...${NC}"
mkdir -p ~/.config
starship preset catppuccin-powerline -o ~/.config/starship.toml
sed -i "s/palette = 'catppuccin_mocha'/palette = 'catppuccin_macchiato'/g" ~/.config/starship.toml

echo -e "\n${GREEN}Zsh and Starship installed and configured. Please restart or open a new terminal to use Zsh.${NC}"

# Final summary
echo -e "\n${GREEN}Installation summary:${NC}"
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ Installation completed successfully! All components were installed correctly.${NC}"
else
  echo -e "${RED}✗ Installation completed with $FAILED errors.${NC}"
fi

# Clean up
sudo apt autoremove -y

echo -e "\n${GREEN}Applying Zsh configuration automatically...${NC}"
# Check if we are in zsh, if not, exec zsh
if [ -n "$ZSH_VERSION" ]; then
   source ~/.zshrc
else
   exec zsh
fi
