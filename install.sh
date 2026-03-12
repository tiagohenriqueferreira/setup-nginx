#!/bin/bash

# Interrompe o script em caso de erro
set -e

echo -e "\n🚀 Ambiente de Desenvolvimento Drupal (Ubuntu + PHP + Nginx + MariaDB)\n"

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
cat << 'ZSHEOF' > ~/.zshrc
# Configuração do Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="af-magic"

# Plugins
plugins=(
  git
  ssh-agent
  zsh-autosuggestions
  fzf
  z
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Configuração do NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Prompt Starship
eval "$(starship init zsh)"

# ─────────────────────────────────────────────
# Funções utilitárias
# ─────────────────────────────────────────────

# Função que executa o Drush independente do diretório atual
drush() {
  local current_dir=$(pwd)
  local project_root=""

  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/vendor/drush/drush/drush" ]]; then
      project_root="$current_dir"
      break
    fi
    current_dir=$(dirname "$current_dir")
  done

  if [[ -n "$project_root" ]]; then
    "$project_root/vendor/drush/drush/drush" "$@"
  else
    echo "Drush não encontrado! Certifique-se de estar dentro de um projeto Drupal."
    return 1
  fi
}

# ─────────────────────────────────────────────
# Permissões
# ─────────────────────────────────────────────

# Corrige permissões de um diretório do Drupal
#
# Uso: fix-perms [diretório]
# Padrão: web/sites/default/files
#
# Permissões aplicadas:
#   Diretórios → 2775 (SGID + rwx dono/grupo, rx outros)
#   Arquivos   → 664  (rw dono/grupo, r outros)
#
fix-perms() {
  local current_user=$(whoami)
  local target_dir="${1:-"web/sites/default/files"}"

  if [ ! -d "$target_dir" ]; then
    if [ -d "sites/default/files" ]; then
      target_dir="sites/default/files"
    else
      echo "Erro: Diretório '$target_dir' não encontrado."
      return 1
    fi
  fi

  echo "Corrigindo permissões para $current_user:www-data em $target_dir..."
  sudo chown -R "$current_user":www-data "$target_dir"
  sudo find "$target_dir" -type d -exec chmod 2775 {} \;
  sudo find "$target_dir" -type f -exec chmod 664 {} \;
  echo "Permissões corrigidas com sucesso!"
}

# ─────────────────────────────────────────────
# Nginx — Vhosts
# ─────────────────────────────────────────────

# Cria um server block do Nginx otimizado para Drupal
#
# Uso: create-vhost <dominio> <caminho_absoluto>
# Exemplo: create-vhost meusite.localhost /var/www/meusite/web
#
# Após criar, o vhost é automaticamente habilitado.
# Para desabilitar: disable-vhost <dominio>
# Para reabilitar:  enable-vhost <dominio>
#
create-vhost() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Uso: create-vhost <dominio> <caminho_absoluto_da_raiz>"
    echo "Exemplo: create-vhost meusite.localhost /var/www/meusite/web"
    echo ""
    echo "Gerenciamento:"
    echo "  disable-vhost <dominio>  - Desabilita o vhost sem apagar o arquivo"
    echo "  enable-vhost <dominio>   - Reabilita um vhost desabilitado"
    return 1
  fi

  local domain=$1
  local root_dir=$2
  local vhost_file="/etc/nginx/sites-available/$domain"

  if [ ! -d "$root_dir" ]; then
    echo "Erro: O diretório $root_dir não existe."
    return 1
  fi

  echo "Criando vhost do Nginx para $domain..."
  cat > "$vhost_file" <<VHOSTEOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    root $root_dir;

    index index.php index.html;

    location / {
        try_files \$uri /index.php?\$query_string;
    }

    location @rewrite {
        rewrite ^/(.*)\$ /index.php?q=\$1;
    }

    location ~ '\.php\$|^/update.php' {
        fastcgi_split_path_info ^(.+?\.php)(|/.*)\$;
        include fastcgi_params;
        include snippets/fastcgi-php.conf;
        fastcgi_param HTTP_PROXY "";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param QUERY_STRING \$query_string;
        fastcgi_intercept_errors on;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        try_files \$uri @rewrite;
        expires max;
        log_not_found off;
    }

    location ~ ^/sites/.*/files/styles/ {
        try_files \$uri @rewrite;
    }

    location ~ ^(/[a-z\-]+)?/system/files/ {
        try_files \$uri /index.php?\$query_string;
    }

    location ~* \.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|twig|tpl(\.php)?|xtmpl)([a-z\-]+)?\$ {
        deny all;
    }
}
VHOSTEOF

  ln -s "$vhost_file" "/etc/nginx/sites-enabled/" 2>/dev/null || true
  sudo systemctl restart nginx
  echo "Vhost criado e habilitado: http://$domain"
}

# Desabilita um vhost (remove o link simbólico sem apagar o arquivo)
#
# Uso: disable-vhost <dominio>
#
disable-vhost() {
  if [ -z "$1" ]; then
    echo "Uso: disable-vhost <dominio>"
    return 1
  fi

  local domain=$1
  local enabled_link="/etc/nginx/sites-enabled/$domain"

  if [ ! -L "$enabled_link" ]; then
    echo "O vhost '$domain' não está habilitado ou não existe."
    return 1
  fi

  rm "$enabled_link"
  sudo systemctl restart nginx
  echo "Vhost '$domain' desabilitado com sucesso."
}

# Habilita um vhost existente
#
# Uso: enable-vhost <dominio>
#
enable-vhost() {
  if [ -z "$1" ]; then
    echo "Uso: enable-vhost <dominio>"
    return 1
  fi

  local domain=$1
  local vhost_file="/etc/nginx/sites-available/$domain"
  local enabled_link="/etc/nginx/sites-enabled/$domain"

  if [ ! -f "$vhost_file" ]; then
    echo "Erro: O arquivo de vhost '/etc/nginx/sites-available/$domain' não existe."
    echo "Use 'create-vhost' para criar um novo vhost."
    return 1
  fi

  if [ -L "$enabled_link" ]; then
    echo "O vhost '$domain' já está habilitado."
    return 0
  fi

  ln -s "$vhost_file" "$enabled_link"
  sudo systemctl restart nginx
  echo "Vhost '$domain' habilitado com sucesso."
}

# ─────────────────────────────────────────────
# MariaDB — Banco de dados
# ─────────────────────────────────────────────

# Cria um banco de dados e usuário no MariaDB
#
# Uso: create-db <nome>
# Cria banco + usuário com o mesmo nome e senha aleatória.
#
create-db() {
  if [ -z "$1" ]; then
    echo "Uso: create-db <nome>"
    echo "Cria um banco de dados e um usuário com o mesmo nome e senha aleatória."
    return 1
  fi

  local name=$1
  local password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

  echo "Criando banco de dados: $name"
  sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`$name\`;"

  echo "Criando usuário: $name"
  sudo mysql -e "CREATE USER IF NOT EXISTS '$name'@'localhost' IDENTIFIED BY '$password';"

  echo "Concedendo privilégios..."
  sudo mysql -e "GRANT ALL PRIVILEGES ON \`$name\`.* TO '$name'@'localhost';"
  sudo mysql -e "FLUSH PRIVILEGES;"

  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║  Banco de dados criado com sucesso!  ║"
  echo "╚══════════════════════════════════════╝"
  echo "  Database: $name"
  echo "  Usuário:  $name"
  echo "  Senha:    $password"
  echo "  Host:     localhost"
  echo ""
  echo "⚠ Guarde essa senha, ela não será exibida novamente!"
}

# Exclui um banco de dados e usuário
#
# Uso: delete-db <nome>
#
delete-db() {
  if [ -z "$1" ]; then
    echo "Uso: delete-db <nome>"
    return 1
  fi

  local name=$1
  read -p "Tem certeza que deseja excluir o banco e o usuário '$name'? [s/N] " confirm

  if [[ $confirm == [sS] || $confirm == [sS][iI][mM] ]]; then
    echo "Excluindo usuário: $name..."
    sudo mysql -e "DROP USER IF EXISTS '$name'@'localhost';"

    echo "Excluindo banco de dados: $name..."
    sudo mysql -e "DROP DATABASE IF EXISTS \`$name\`;"

    echo "Banco de dados e usuário '$name' removidos com sucesso!"
  else
    echo "Operação cancelada."
  fi
}

# ─────────────────────────────────────────────
# Drupal — Inicialização e ajuste
# ─────────────────────────────────────────────

# Inicializa um projeto Drupal (executar na raiz do projeto)
#
# Uso: init-drupal
#
# O que faz:
#   - Copia default.settings.php para settings.php
#   - Dá permissões de escrita
#   - Cria diretórios files/ e private_files/
#   - Corrige permissões
#
init-drupal() {
  local settings_dir="web/sites/default"
  local default_file="$settings_dir/default.settings.php"
  local settings_file="$settings_dir/settings.php"

  if [ ! -d "$settings_dir" ]; then
    echo "Erro: Diretório '$settings_dir' não encontrado. Você está na raiz do projeto Drupal?"
    return 1
  fi

  if [ ! -f "$default_file" ]; then
    echo "Erro: '$default_file' não encontrado."
    return 1
  fi

  echo "Copiando default.settings.php para settings.php..."
  cp "$default_file" "$settings_file"

  echo "Dando permissão de escrita ao settings.php..."
  chmod 666 "$settings_file"
  chmod 775 "$settings_dir"

  echo "Criando diretórios 'files' e 'private_files'..."
  mkdir -p "$settings_dir/files"
  mkdir -p "$settings_dir/private_files"

  echo "Corrigindo permissões dos diretórios..."
  fix-perms "$settings_dir/files"
  fix-perms "$settings_dir/private_files"

  echo "init-drupal concluído! Instale o Drupal pelo navegador."
  echo "Após a instalação, rode: adjust-drupal"
}

# Ajusta o Drupal após a instalação
# Detecta automaticamente os domínios pelos vhosts do Nginx
#
# Uso: adjust-drupal (na raiz do projeto)
#
# O que faz:
#   - Remove o diretório config* criado dentro de files/
#   - Remove permissão de escrita do settings.php
#   - Remove linhas existentes de config_sync, private_path e trusted_host
#   - Adiciona o caminho correto do config_sync_directory
#   - Adiciona o caminho do private_files
#   - Adiciona o trusted_host_patterns com os domínios detectados
#
adjust-drupal() {
  local settings_dir="web/sites/default"
  local settings_file="$settings_dir/settings.php"
  local project_web=$(pwd)/web

  if [ ! -d "$settings_dir" ]; then
    echo "Erro: Diretório '$settings_dir' não encontrado. Você está na raiz do projeto Drupal?"
    return 1
  fi

  if [ ! -f "$settings_file" ]; then
    echo "Aviso: '$settings_file' não encontrado. Rode 'init-drupal' primeiro."
    return 1
  fi

  # Detectar domínios automaticamente pelos vhosts do Nginx
  local domains=()
  for vhost in /etc/nginx/sites-available/*; do
    if grep -q "$project_web" "$vhost" 2>/dev/null; then
      domains+=($(basename "$vhost"))
    fi
  done

  if [ ${#domains[@]} -eq 0 ]; then
    echo "Erro: Nenhum vhost encontrado apontando para $project_web"
    echo "Crie um vhost primeiro com: create-vhost <dominio> $project_web"
    return 1
  fi

  echo "Domínios detectados: ${domains[*]}"

  # Remover diretório config* que o Drupal cria dentro de files/
  echo "Removendo diretório config* de dentro de files/..."
  rm -rf "$settings_dir"/files/config_*

  # Desbloquear diretório sites/default para permitir edição
  chmod 775 "$settings_dir"

  # Dar permissão temporária de escrita para editar o settings.php
  chmod 666 "$settings_file"

  # Remover bloco de configurações anteriores do adjust-drupal (se existir)
  echo "Removendo configurações anteriores..."
  sed -i '/\/\/ Configurações adicionadas por adjust-drupal/,$d' "$settings_file"

  # Adicionar novas configurações no final do arquivo
  echo "Adicionando configurações no settings.php..."
  {
    echo ""
    echo "// Configurações adicionadas por adjust-drupal"
    echo "\$settings['config_sync_directory'] = '../config/sync';"
    echo "\$settings['file_private_path'] = \$app_root . '/sites/default/private_files';"
    echo "\$settings['trusted_host_patterns'] = ["
    for d in "${domains[@]}"; do
      local d_escaped=${d//./\\.}
      echo "  '^${d_escaped}$',"
    done
    echo "];"
  } >> "$settings_file"

  # Remover permissão de escrita do settings.php
  echo "Travando settings.php e diretório $settings_dir..."
  chmod 444 "$settings_file"

  # Corrigir permissões apenas de files/ e private_files/
  echo "Corrigindo permissões de files/ e private_files/..."
  fix-perms "$settings_dir/files"
  fix-perms "$settings_dir/private_files"

  # Travar o diretório sites/default (exigência do Drupal)
  sudo chmod 555 "$settings_dir"

  echo "adjust-drupal concluído!"
  echo "  ✓ config* removido de files/"
  echo "  ✓ config_sync_directory → ../config/sync"
  echo "  ✓ file_private_path configurado"
  echo "  ✓ trusted_host_patterns → ${domains[*]}"
  echo "  ✓ Permissões corrigidas em files/ e private_files/"
  echo "  ✓ settings.php travado (somente leitura)"
  echo "  ✓ $settings_dir travado (somente leitura)"
}

# ─────────────────────────────────────────────
# Aliases
# ─────────────────────────────────────────────

alias sites="cd /var/www/"
alias vhosts="cd /etc/nginx/sites-available/"
alias update="sudo nala update && sudo nala list --upgradable && sudo nala upgrade -y"
alias rnx="sudo service nginx restart"
alias rmdb="sudo service mariadb restart"
alias logs="tail -f /var/log/nginx/error.log"
alias phplog="tail -f /var/log/php8.4-fpm.log"
alias fp="fix-perms"
alias ss1="npx sass scss/style.scss css/style.css -w --no-source-map"
alias ss2="npx sass scss/ck5style.scss css/ck5style.css -w --no-source-map"

ZSHEOF

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
