#!/bin/bash

# Interrompe o script em caso de erro
set -e

echo -e "\n🚀 Ambiente de Desenvolvimento Drupal para Ubuntu (PHP / Nginx / MariaDB)\n"

# Definição de cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Atualização e upgrade de pacotes
echo -e "${GREEN}Atualizando pacotes...${NC}"
sudo apt update && sudo apt list --upgradable && sudo apt upgrade -y

# Instalar o Nala
echo -e "\n${GREEN}Instalando Nala...${NC}"
sudo apt install nala software-properties-common -y

# Adicionar PPA do PHP
echo -e "\n${GREEN}Adicionando PPA do PHP...${NC}"
sudo add-apt-repository ppa:ondrej/php -y

# Atualizar com Nala
echo -e "\n${GREEN}Atualizando com Nala...${NC}"
sudo nala update && sudo nala list --upgradable && sudo nala upgrade -y

# Lista de pacotes para instalar
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

# Instalar pacotes via Nala (--no-install-recommends impede o Apache2 de ser instalado)
echo -e "\n${GREEN}Instalando pacotes...${NC}"
sudo nala install -y --no-install-recommends "${PACKAGES[@]}"

# Garantir que o Apache2 esteja completamente removido
echo -e "\n${GREEN}Garantindo que o Apache2 não está presente...${NC}"
sudo systemctl stop apache2 2>/dev/null || true
sudo systemctl disable apache2 2>/dev/null || true
sudo apt-get purge -y 'apache2*' 'libapache2*' 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true

# Definir PHP 8.4 como padrão
echo -e "\n${GREEN}Definindo PHP 8.4 como padrão...${NC}"
sudo update-alternatives --set php /usr/bin/php8.4
sudo update-alternatives --set phar /usr/bin/phar8.4
sudo update-alternatives --set phar.phar /usr/bin/phar.phar8.4

# Instalação do Composer
echo -e "\n${GREEN}Instalando Composer...${NC}"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === file_get_contents('https://composer.github.io/installer.sig')) { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); exit(1); }"
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

# Instalação do FastFetch via PPA
echo -e "\n${GREEN}Instalando FastFetch...${NC}"
sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
sudo nala update
sudo nala install -y fastfetch

# Permissões dos diretórios para o usuário atual
echo -e "\n${GREEN}Configurando permissões dos diretórios...${NC}"
CURRENT_USER=$(whoami)
sudo chown -R "$CURRENT_USER":www-data /var/www
sudo chmod -R 2775 /var/www
sudo chown -R "$CURRENT_USER":www-data /etc/nginx/sites-available
sudo chown -R "$CURRENT_USER":www-data /etc/nginx/sites-enabled

# Ajustar configurações do PHP
echo -e "\n${GREEN}Ajustando configurações do PHP...${NC}"
PHP_INI="/etc/php/8.4/fpm/php.ini"
sudo sed -i 's/memory_limit = .*/memory_limit = 2048M/' "$PHP_INI"
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 512M/' "$PHP_INI"
sudo sed -i 's/post_max_size = .*/post_max_size = 2048M/' "$PHP_INI"
sudo sed -i 's/max_execution_time = .*/max_execution_time = 180/' "$PHP_INI"
sudo sed -i 's/max_input_time = .*/max_input_time = 180/' "$PHP_INI"

# Configurar APCu
echo -e "\n${GREEN}Configurando APCu...${NC}"
DETECTED_PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
APCU_INI="/etc/php/${DETECTED_PHP_VERSION}/mods-available/apcu.ini"
echo "extension=apcu.so" | sudo tee "$APCU_INI" > /dev/null
echo "apc.shm_size=128M" | sudo tee -a "$APCU_INI" > /dev/null
sudo phpenmod -v "${DETECTED_PHP_VERSION}" apcu

# Reiniciar Nginx e PHP-FPM
sudo systemctl restart nginx php8.4-fpm

# Verificar se os serviços estão rodando
echo -e "\n${GREEN}Verificando status da instalação...${NC}"

check_service() {
  if systemctl is-active --quiet "$1"; then
    echo -e "${GREEN}✓ $1 está rodando${NC}"
    return 0
  else
    echo -e "${RED}✗ $1 falhou ao iniciar${NC}"
    return 1
  fi
}

SERVICES=(nginx php8.4-fpm mariadb)
FAILED=0

for SERVICE in "${SERVICES[@]}"; do
  check_service "$SERVICE" || FAILED=$((FAILED + 1))
done

# Verificar instalação do PHP
if command -v php &> /dev/null; then
  INSTALLED_PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2)
  echo -e "${GREEN}✓ PHP $INSTALLED_PHP_VERSION instalado${NC}"

  # Verificar suporte AVIF
  if php -i | grep -q "AVIF Support => enabled"; then
      echo -e "${GREEN}✓ Suporte AVIF do PHP GD habilitado${NC}"
  else
      echo -e "${YELLOW}⚠ Suporte AVIF do PHP GD não encontrado (verifique libavif)${NC}"
  fi
else
  echo -e "${RED}✗ Instalação do PHP falhou${NC}"
  FAILED=$((FAILED + 1))
fi

# Verificar instalação do Composer
if command -v composer &> /dev/null; then
  COMPOSER_VERSION=$(composer --version | cut -d' ' -f2)
  echo -e "${GREEN}✓ Composer $COMPOSER_VERSION instalado${NC}"
else
  echo -e "${RED}✗ Instalação do Composer falhou${NC}"
  FAILED=$((FAILED + 1))
fi

# Instalar Zsh e Oh My Zsh
echo -e "\n${GREEN}Instalando Zsh e Oh My Zsh...${NC}"
sudo nala install -y zsh

# Backup do .zshrc existente
if [ -f ~/.zshrc ]; then
    echo -e "${YELLOW}Fazendo backup do .zshrc existente para .zshrc.backup...${NC}"
    cp ~/.zshrc ~/.zshrc.backup
fi

# Instalar Oh My Zsh (sem interação)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Definir Zsh como shell padrão
chsh -s "$(which zsh)"

# Clonar repositórios de plugins
mkdir -p "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
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

# Configurar Zsh
echo -e "\n${GREEN}Configurando Zsh...${NC}"
{
  echo "# Configuração do Oh My Zsh"
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
  echo "source \$ZSH/oh-my-zsh.sh"
  echo ""
  echo "# Configuração do NVM"
  echo "export NVM_DIR=\"\\\$HOME/.nvm\""
  echo "[ -s \"\\\$NVM_DIR/nvm.sh\" ] && \\. \"\\\$NVM_DIR/nvm.sh\""
  echo "[ -s \"\\\$NVM_DIR/bash_completion\" ] && \\. \"\\\$NVM_DIR/bash_completion\""
  echo ""
  echo "# Prompt Starship"
  echo "eval \"\$(starship init zsh)\""
  echo ""
  echo "# Função que executa o Drush independente do diretório atual"
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
  echo "    echo \"Drush não encontrado! Certifique-se de estar dentro de um projeto Drupal.\""
  echo "    return 1"
  echo "  fi"
  echo "}"
  echo ""
  echo "# Função para corrigir permissões do diretório files do Drupal"
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
  echo "  echo \"Corrigindo permissões para \$current_user:www-data em \$target_dir...\""
  echo "  sudo chown -R \$current_user:www-data \$target_dir"
  echo "  sudo chmod -R 2775 \$target_dir"
  echo "  sudo setfacl -R -m u:\${current_user}:rwx \$target_dir"
  echo "  sudo setfacl -R -m g:www-data:rwx \$target_dir"
  echo "  sudo setfacl -R -d -m u:\${current_user}:rwx \$target_dir"
  echo "  sudo setfacl -R -d -m g:www-data:rwx \$target_dir"
  echo "  echo \"Permissões corrigidas com sucesso!\""
  echo "}"
  echo ""
  echo "# Função para criar um vhost do Nginx"
  echo "#"
  echo "# Uso: create-vhost <dominio> <caminho_absoluto>"
  echo "# Exemplo: create-vhost meusite.localhost /var/www/meusite/web"
  echo "#"
  echo "# Após criar, o vhost é automaticamente habilitado."
  echo "# Para desabilitar: disable-vhost <dominio>"
  echo "# Para reabilitar:  enable-vhost <dominio>"
  echo "#"
  echo "create-vhost() {"
  echo "  if [ -z \"\$1\" ] || [ -z \"\$2\" ]; then"
  echo "    echo \"Uso: create-vhost <dominio> <caminho_absoluto_da_raiz>\""
  echo "    echo \"Exemplo: create-vhost meusite.localhost /var/www/meusite/web\""
  echo "    echo \"\""
  echo "    echo \"Gerenciamento:\""
  echo "    echo \"  disable-vhost <dominio>  - Desabilita o vhost sem apagar o arquivo\""
  echo "    echo \"  enable-vhost <dominio>   - Reabilita um vhost desabilitado\""
  echo "    return 1"
  echo "  fi"
  echo "  local domain=\$1"
  echo "  local root_dir=\$2"
  echo "  local vhost_file=\"/etc/nginx/sites-available/\$domain\""
  echo ""
  echo "  if [ ! -d \"\$root_dir\" ]; then"
  echo "    echo \"Erro: O diretório \$root_dir não existe.\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  echo \"Criando vhost do Nginx para \$domain...\""
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
  echo "  echo \"Vhost criado e habilitado: http://\$domain\""
  echo "}"
  echo ""
  echo "# Função para desabilitar um vhost (remove o link simbólico)"
  echo "disable-vhost() {"
  echo "  if [ -z \"\$1\" ]; then"
  echo "    echo \"Uso: disable-vhost <dominio>\""
  echo "    return 1"
  echo "  fi"
  echo "  local domain=\$1"
  echo "  local enabled_link=\"/etc/nginx/sites-enabled/\$domain\""
  echo ""
  echo "  if [ ! -L \"\$enabled_link\" ]; then"
  echo "    echo \"O vhost '\$domain' não está habilitado ou não existe.\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  rm \"\$enabled_link\""
  echo "  sudo systemctl restart nginx"
  echo "  echo \"Vhost '\$domain' desabilitado com sucesso.\""
  echo "}"
  echo ""
  echo "# Função para habilitar um vhost existente"
  echo "enable-vhost() {"
  echo "  if [ -z \"\$1\" ]; then"
  echo "    echo \"Uso: enable-vhost <dominio>\""
  echo "    return 1"
  echo "  fi"
  echo "  local domain=\$1"
  echo "  local vhost_file=\"/etc/nginx/sites-available/\$domain\""
  echo "  local enabled_link=\"/etc/nginx/sites-enabled/\$domain\""
  echo ""
  echo "  if [ ! -f \"\$vhost_file\" ]; then"
  echo "    echo \"Erro: O arquivo de vhost '/etc/nginx/sites-available/\$domain' não existe.\""
  echo "    echo \"Use 'create-vhost' para criar um novo vhost.\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  if [ -L \"\$enabled_link\" ]; then"
  echo "    echo \"O vhost '\$domain' já está habilitado.\""
  echo "    return 0"
  echo "  fi"
  echo ""
  echo "  ln -s \"\$vhost_file\" \"\$enabled_link\""
  echo "  sudo systemctl restart nginx"
  echo "  echo \"Vhost '\$domain' habilitado com sucesso.\""
  echo "}"
  echo ""
  echo "# Função para criar um banco de dados e usuário no MariaDB"
  echo "create-db() {"
  echo "  if [ -z \"\$1\" ]; then"
  echo "    echo \"Uso: create-db <nome>\""
  echo "    echo \"Cria um banco de dados e um usuário com o mesmo nome e senha aleatória.\""
  echo "    return 1"
  echo "  fi"
  echo "  local name=\$1"
  echo "  local password=\$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)"
  echo "  echo \"Criando banco de dados: \$name\""
  echo "  sudo mysql -e \"CREATE DATABASE IF NOT EXISTS \\\`\$name\\\`;\""
  echo "  echo \"Criando usuário: \$name\""
  echo "  sudo mysql -e \"CREATE USER IF NOT EXISTS '\$name'@'localhost' IDENTIFIED BY '\$password';\""
  echo "  echo \"Concedendo privilégios...\""
  echo "  sudo mysql -e \"GRANT ALL PRIVILEGES ON \\\`\$name\\\`.* TO '\$name'@'localhost';\""
  echo "  sudo mysql -e \"FLUSH PRIVILEGES;\""
  echo "  echo \"\""
  echo "  echo \"╔══════════════════════════════════════╗\""
  echo "  echo \"║  Banco de dados criado com sucesso!  ║\""
  echo "  echo \"╚══════════════════════════════════════╝\""
  echo "  echo \"  Database: \$name\""
  echo "  echo \"  Usuário:  \$name\""
  echo "  echo \"  Senha:    \$password\""
  echo "  echo \"  Host:     localhost\""
  echo "  echo \"\""
  echo "  echo \"⚠ Guarde essa senha, ela não será exibida novamente!\""
  echo "}"
  echo ""
  echo "# Função para excluir um banco de dados e usuário"
  echo "delete-db() {"
  echo "  if [ -z \"\$1\" ]; then"
  echo "    echo \"Uso: delete-db <nome>\""
  echo "    return 1"
  echo "  fi"
  echo "  local name=\$1"
  echo "  read -p \"Tem certeza que deseja excluir o banco e o usuário '\$name'? [s/N] \" confirm"
  echo "  if [[ \$confirm == [sS] || \$confirm == [sS][iI][mM] ]]; then"
  echo "    echo \"Excluindo usuário: \$name...\""
  echo "    sudo mysql -e \"DROP USER IF EXISTS '\$name'@'localhost';\""
  echo "    echo \"Excluindo banco de dados: \$name...\""
  echo "    sudo mysql -e \"DROP DATABASE IF EXISTS \\\`\$name\\\`;\""
  echo "    echo \"Banco de dados e usuário '\$name' removidos com sucesso!\""
  echo "  else"
  echo "    echo \"Operação cancelada.\""
  echo "  fi"
  echo "}"
  echo ""
  echo "# Função para inicializar um projeto Drupal"
  echo "# Copia default.settings.php, dá permissões e cria diretórios files/private_files"
  echo "init-drupal() {"
  echo "  local settings_dir=\"web/sites/default\""
  echo "  local default_file=\"\$settings_dir/default.settings.php\""
  echo "  local settings_file=\"\$settings_dir/settings.php\""
  echo ""
  echo "  if [ ! -d \"\$settings_dir\" ]; then"
  echo "    echo \"Erro: Diretório '\$settings_dir' não encontrado. Você está na raiz do projeto Drupal?\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  if [ ! -f \"\$default_file\" ]; then"
  echo "    echo \"Erro: '\$default_file' não encontrado.\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  echo \"Copiando default.settings.php para settings.php...\""
  echo "  cp \"\$default_file\" \"\$settings_file\""
  echo ""
  echo "  echo \"Dando permissão de escrita ao settings.php...\""
  echo "  chmod 666 \"\$settings_file\""
  echo "  chmod 775 \"\$settings_dir\""
  echo ""
  echo "  echo \"Criando diretórios 'files' e 'private_files'...\""
  echo "  mkdir -p \"\$settings_dir/files\""
  echo "  mkdir -p \"\$settings_dir/private_files\""
  echo ""
  echo "  echo \"Corrigindo permissões dos diretórios...\""
  echo "  fix-perms"
  echo "  fix-perms web/sites/default/private_files"
  echo ""
  echo "  echo \"init-drupal concluído! Instale o Drupal pelo navegador.\""
  echo "  echo \"Após a instalação, rode: adjust-drupal\""
  echo "}"
  echo ""
  echo "# Função para ajustar o Drupal após a instalação"
  echo "# Detecta automaticamente o domínio pelo vhost do Nginx"
  echo "#"
  echo "# O que faz:"
  echo "#   - Remove o diretório config* criado dentro de files/"
  echo "#   - Remove permissão de escrita do settings.php"
  echo "#   - Remove linhas existentes de config_sync, private_path e trusted_host"
  echo "#   - Adiciona o caminho correto do config_sync_directory"
  echo "#   - Adiciona o caminho do private_files"
  echo "#   - Adiciona o trusted_host_patterns com o domínio detectado"
  echo "#"
  echo "adjust-drupal() {"
  echo "  local settings_dir=\"web/sites/default\""
  echo "  local settings_file=\"\$settings_dir/settings.php\""
  echo "  local project_web=\$(pwd)/web"
  echo ""
  echo "  if [ ! -d \"\$settings_dir\" ]; then"
  echo "    echo \"Erro: Diretório '\$settings_dir' não encontrado. Você está na raiz do projeto Drupal?\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  if [ ! -f \"\$settings_file\" ]; then"
  echo "    echo \"Aviso: '\$settings_file' não encontrado. Rode 'init-drupal' primeiro.\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  # Detectar domínios automaticamente pelos vhosts do Nginx"
  echo "  local domains=()"
  echo "  for vhost in /etc/nginx/sites-available/*; do"
  echo "    if grep -q \"\$project_web\" \"\$vhost\" 2>/dev/null; then"
  echo "      domains+=(\$(basename \"\$vhost\"))"
  echo "    fi"
  echo "  done"
  echo ""
  echo "  if [ \${#domains[@]} -eq 0 ]; then"
  echo "    echo \"Erro: Nenhum vhost encontrado apontando para \$project_web\""
  echo "    echo \"Crie um vhost primeiro com: create-vhost <dominio> \$project_web\""
  echo "    return 1"
  echo "  fi"
  echo ""
  echo "  echo \"Domínios detectados: \${domains[*]}\""
  echo ""
  echo "  # Remover diretório config* que o Drupal cria dentro de files/"
  echo "  echo \"Removendo diretório config* de dentro de files/...\""
  echo "  rm -rf \"\$settings_dir\"/files/config_*"
  echo ""
  echo "  # Dar permissão temporária de escrita para editar o settings.php"
  echo "  chmod 666 \"\$settings_file\""
  echo ""
  echo "  # Remover linhas existentes"
  echo "  echo \"Removendo definições existentes...\""
  echo "  sed -i '/config_sync_directory/d' \"\$settings_file\""
  echo "  sed -i '/trusted_host_patterns/d' \"\$settings_file\""
  echo "  sed -i '/file_private_path/d' \"\$settings_file\""
  echo ""
  echo "  # Adicionar novas configurações no final do arquivo"
  echo "  echo \"Adicionando configurações no settings.php...\""
  echo "  {"
  echo "    echo \"\""
  echo "    echo \"// Configurações adicionadas por adjust-drupal\""
  echo '    echo "\$settings['"'"'config_sync_directory'"'"'] = '"'"'../config/sync'"'"';"'
  echo '    echo "\$settings['"'"'file_private_path'"'"'] = \$app_root . '"'"'/sites/default/private_files'"'"';"'
  echo '    echo "\$settings['"'"'trusted_host_patterns'"'"'] = ["'
  echo "    for d in \"\${domains[@]}\"; do"
  echo '      local d_escaped=${d//./\\.}'
  echo '      echo "  '"'"'^${d_escaped}$'"'"',"'
  echo "    done"
  echo "    echo \"];\""
  echo "  } >> \"\$settings_file\""
  echo ""
  echo "  # Remover permissão de escrita do settings.php"
  echo "  echo \"Removendo permissão de escrita do settings.php...\""
  echo "  chmod 444 \"\$settings_file\""
  echo ""
  echo "  echo \"Corrigindo permissões...\""
  echo "  fix-perms \"\$settings_dir/files\""
  echo "  fix-perms \"\$settings_dir/private_files\""
  echo ""
  echo "  echo \"adjust-drupal concluído!\""
  echo "  echo \"  ✓ config* removido de files/\""
  echo "  echo \"  ✓ config_sync_directory → ../config/sync\""
  echo "  echo \"  ✓ file_private_path configurado\""
  echo "  echo \"  ✓ trusted_host_patterns → \${domains[*]}\""
  echo "  echo \"  ✓ Permissões corrigidas em files/ e private_files/\""
  echo "  echo \"  ✓ settings.php travado (somente leitura)\""
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
  echo "alias ss1=\"npx sass scss/style.scss css/style.css -w --no-source-map\""
  echo "alias ss2=\"npx sass scss/ck5style.scss css/ck5style.css -w --no-source-map\""
  echo ""
} > ~/.zshrc

echo -e "\n${GREEN}Instalando Starship...${NC}"
curl -sS https://starship.rs/install.sh | sh -s -- -y

echo -e "\n${GREEN}Instalando NVM e Node.js LTS...${NC}"
export NVM_DIR="$HOME/.nvm"
curl -sL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'

echo -e "\n${GREEN}Configurando Starship com Catppuccin Powerline (Macchiato)...${NC}"
mkdir -p ~/.config
starship preset catppuccin-powerline -o ~/.config/starship.toml
sed -i "s/palette = 'catppuccin_mocha'/palette = 'catppuccin_macchiato'/g" ~/.config/starship.toml

echo -e "\n${GREEN}Zsh e Starship instalados e configurados.${NC}"

# Resumo final
echo -e "\n${GREEN}Resumo da instalação:${NC}"
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ Instalação concluída com sucesso! Todos os componentes foram instalados corretamente.${NC}"
else
  echo -e "${RED}✗ Instalação concluída com $FAILED erro(s).${NC}"
fi

# Limpeza
sudo apt autoremove -y

echo -e "\n${GREEN}Aplicando configuração do Zsh automaticamente...${NC}"
if [ -n "$ZSH_VERSION" ]; then
   source ~/.zshrc
else
   exec zsh
fi
