# 🚀 Drupal Setup — Nginx + PHP-FPM + MariaDB

Script de configuração automática de um ambiente de desenvolvimento Drupal 10/11 em distribuições Ubuntu (WSL ou nativo).

## Instalação

```bash
git clone https://github.com/tiagohenriqueferreira/setup-nginx.git ~/setup-nginx
cd ~/setup-nginx
chmod +x install.sh
./install.sh
```

## O que é instalado

| Software | Detalhes |
|---|---|
| Nginx | Servidor web principal |
| PHP 8.4-FPM | Com módulos: mysql, gd, xml, mbstring, curl, zip, intl, bcmath, opcache, apcu, uploadprogress, imagick, ldap |
| MariaDB | Banco de dados |
| Composer | Gerenciador de dependências PHP |
| NVM | Node Version Manager com Node.js LTS |
| Zsh | Shell padrão com Oh My Zsh |
| Starship | Prompt customizado (preset Catppuccin Powerline Macchiato) |
| FastFetch | Informações do sistema no terminal |
| SASS | Via `npx` (instalado pelo Node.js) |

## Configuração do PHP

O script ajusta automaticamente o `php.ini` do FPM:

| Diretiva | Valor |
|---|---|
| `memory_limit` | 2048M |
| `upload_max_filesize` | 512M |
| `post_max_size` | 2048M |
| `max_execution_time` | 180s |
| `max_input_time` | 180s |
| APCu `shm_size` | 128M |

## Funções disponíveis no terminal

Após a instalação, o seu `.zshrc` terá estas funções prontas para uso:

### Automação Nginx e Banco de Dados

| Comando | O que faz |
|---|---|
| `init-drupal` | Na raiz do projeto: copia `default.settings.php` para `settings.php` e dá as permissões para instalação |
| `adjust-drupal` | Após instalar o Drupal: cria `files/`, `private_files/`, configura `config_sync_directory` e `file_private_path` no `settings.php` e corrige permissões |
| `create-vhost <dominio> <diretorio>` | Cria um server block do Nginx otimizado para Drupal e reinicia o serviço |
| `create-db <nome>` | Cria banco de dados + usuário no MariaDB (mesmo nome e senha) |
| `delete-db <nome>` | Exclui banco de dados e usuário (pede confirmação) |
| `fix-perms [dir]` | Corrige permissões do diretório de arquivos do Drupal para `usuario:www-data` |
| `drush` | Wrapper global que encontra e executa o Drush local do projeto automaticamente |

### Aliases

| Alias | Comando |
|---|---|
| `sites` | `cd /var/www/` |
| `vhosts` | `cd /etc/nginx/sites-available/` |
| `update` | Atualiza e faz upgrade de todos os pacotes via Nala |
| `rnx` | Reinicia o Nginx |
| `rmdb` | Reinicia o MariaDB |
| `logs` | `tail -f` no log de erros do Nginx |
| `phplog` | `tail -f` no log do PHP-FPM |
| `fp` | Atalho para `fix-perms` |
| `ss1` | Compila `scss/style.scss` → `css/style.css` em watch mode |
| `ss2` | Compila `scss/ck5style.scss` → `css/ck5style.css` em watch mode |

## Permissões

O script configura automaticamente:

- `/var/www` — propriedade do seu usuário com grupo `www-data`
- `/etc/nginx/sites-available` e `sites-enabled` — editáveis sem `sudo`
- Diretórios `files/` do Drupal — permissões via ACL (`setfacl`)

## Shell e Plugins

- **Zsh** como shell padrão
- **Oh My Zsh** com os plugins: `git`, `ssh-agent`, `zsh-autosuggestions`, `fzf`, `z`, `zsh-syntax-highlighting`
- **Starship** com o preset `catppuccin-powerline` (flavor `macchiato`)

## Troubleshooting

| Problema | Solução |
|---|---|
| Nginx não inicia | `sudo netstat -tuln \| grep 80` para verificar conflito de porta |
| Apache2 instalado | O script já remove automaticamente, mas se persistir: `sudo apt purge 'apache2*'` |
| Permissões no `/var/www` | `fp` ou `fix-perms` na pasta do projeto |
| Logs do sistema | `sudo journalctl -xeu nginx` ou `sudo journalctl -xeu php8.4-fpm` |

---

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange.svg)
![Nginx](https://img.shields.io/badge/Nginx-Latest-green.svg)
![PHP](https://img.shields.io/badge/PHP-8.4--FPM-purple.svg)
![MariaDB](https://img.shields.io/badge/MariaDB-Latest-blue.svg)
![Composer](https://img.shields.io/badge/Composer-Latest-yellow.svg)
![NVM](https://img.shields.io/badge/NVM-Latest-green.svg)
![Zsh](https://img.shields.io/badge/Zsh-Oh_My_Zsh-yellow.svg)
![Starship](https://img.shields.io/badge/Starship-Catppuccin-pink.svg)
