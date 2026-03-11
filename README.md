# Drupal on Ubuntu

Drupal on Ubuntu is a project that facilitates quick configuration of Ubuntu-based distributions for people who want to work with Drupal 10/11.

## 🚀 Installation

To install, clone the repository and run the configuration script:

```bash
cd ~
git clone https://github.com/tiagohenriqueferreira/setup-nginx.git
cd setup-nginx
sudo chmod +x install.sh
./install.sh
```

## 📦 Installed Software

The script automatically installs and configures:

- Nginx
- PHP 8.4-FPM + Essential modules
- Composer
- MariaDB
- FFmpeg
- NVM (Node Version Manager) com NodeJS LTS e Npm

## 💡 Features

- Automated environment configuration
- Installation of essential packages
- Development environment setup
- Performance optimizations

## 💻 System Requirements

- Ubuntu 22.04 LTS or newer Ubuntu-based distribution
- Root/sudo access
- Internet connection
- Minimum 4GB RAM recommended
- 20GB disk space

## 🐘 PHP Configuration

The script automatically configures PHP-FPM with the following limits:

- memory_limit = 2048M
- upload_max_filesize = 512M
- post_max_size = 2048M
- max_execution_time = 180
- max_input_time = 180

Additionally, PHP APCu (Alternative PHP Cache) is configured with 128MB of shared memory for improved performance, providing better caching and faster response times for Drupal.

## 🔧 Usage

After installation, you have some new tools in your `.zshrc`:

### 💻 Nginx & Database Automation Functions

Estas funções facilitam muito o dia a dia, gerando de maneira automatizada vhosts do Nginx ou bancos de dados locais.

- `init-drupal` - Executado na raiz do seu projeto, esse comando cria os diretórios `files` e `private_files` no local padrão, aponta as váriaveis `$settings['config_sync_directory']` e `$settings['file_private_path']` no seu `settings.php` e acerta as permissões do diretório para o Nginx.
- `create-vhost <dominio> <diretorio>` - Cria um Vhost Nginx perfeito pro Drupal e reinicia o Nginx.
- `create-db <nome>` - Cria um banco de dados e usuário no MariaDB com acesso total.
- `delete-db <nome>` - Exclui um banco de dados e seu usuário.

### 🛠️ Bash Aliases

- `drush` - Shortcut for Drush (`./vendor/drush/drush/drush`)
- `sites` - Navigate to `/var/www/`
- `vhosts` - Navigate to `/etc/nginx/sites-available/`
- `update` - Update packages and upgrade automatically using Nala
- `upgrade` - Install packages listed as upgradable using Nala
- `rnx` - Restart Nginx service (`sudo service nginx restart`)
- `rmdb` - Restart MariaDB service (`sudo service mariadb restart`)
- `ss1` - Compiles `scss/style.scss` to `css/style.css` using `npx sass` in watch mode
- `ss2` - Compiles `scss/ck5style.scss` to `css/ck5style.css` using `npx sass` in watch mode
- `logs` - Tails the Nginx error log in real time (`/var/log/nginx/error.log`)
- `phplog` - Tails the PHP-FPM error log in real time (`/var/log/php8.4-fpm.log`)

- `fp` - Fix permissions on Drupal files directory

## 🔍 Troubleshooting

- If Nginx doesn't start, check ports with: `sudo netstat -tuln | grep 80`
- For permission issues: `sudo chown -R www-data:www-data /var/www/html`
- System logs: `sudo journalctl -xe`

## 🐚 Shell Configuration

The script installs and configures:

- Zsh as default shell
- Oh My Zsh with af-magic theme
- Plugins: git, ssh-agent, zsh-autosuggestions, zsh-syntax-highlighting, fzf, z

## 🔒 Security

Remember to:

- Change default database passwords
- Configure firewalls properly
- Keep the system updated using provided aliases

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add: new feature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📬 Contact

Tiago Henrique Ferreira - [tiagohenriqueferreira@gmail.com](mailto:tiagohenriqueferreira@gmail.com)

Project Link: [https://github.com/tiagohenriqueferreira/setup-nginx](https://github.com/tiagohenriqueferreira/setup-nginx)

## 📝 License

This project is under the MIT License. See the `LICENSE` file for more information.

---

![Ubuntu](https://img.shields.io/badge/Ubuntu-Latest-orange.svg)
![Zsh](https://img.shields.io/badge/Zsh-Latest-yellow.svg)
![Nginx](https://img.shields.io/badge/Nginx-Latest-green.svg)
![PHP Version](https://img.shields.io/badge/PHP-Latest-purple.svg)
![Composer](https://img.shields.io/badge/Composer-Latest-yellow.svg)
![MariaDB](https://img.shields.io/badge/MariaDB-Latest-blue.svg)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Latest-blue.svg)
![NVM](https://img.shields.io/badge/NVM-Latest-green.svg)
