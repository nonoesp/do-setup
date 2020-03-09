DOTENV_PATH=./.env

include .env
export

################################################
# Automation for root account
################################################

# Util
MYSQL_SHOW=SHOW DATABASES;SELECT user FROM mysql.user;

setup:
	@make setup_root_account

setup_user:
	@make setup_user_account

# To be run as root
setup_root_account:
	@make git_user_setup
	#@make git_swap_https_to_ssh
	@make user_create
	@make user_copy_do_setup
	@make php73_install
	@make phpmyadmin
	@make mysql_up
	@make www_html_index
	@make www_privileges
	@make ssh_key_create
	@make ssh_key_print
	@make ssh_key_add_bash_agent
	@make swap_space_increase
	@make nginx_setup_client_max_body_size

# To be run as ${MACHINE_USERNAME}
setup_user_account:
	@make git_user_setup
	@make git_swap_https_to_ssh
	@make ssh_key_create
	@make ssh_key_print
	@make ssh_key_add_bash_agent
	@make php_setup

root_dotenv_exists:
	@test -f $(DOTENV_PATH) && \
	(\
	echo "## Environment file exists (at $(DOTENV_PATH) )." \
	) \
	|| \
	( \
	echo "## Environment file does not exist (at $(DOTENV_PATH) )." && \
	echo "## Creating.." && \
	cp ./.env.example $(DOTENV_PATH) \
	)

user_create:
	@echo "Creating user ${MACHINE_USERNAME}.."
	adduser $(MACHINE_USERNAME)
	@echo "Providing sudo priveleges to ${MACHINE_USERNAME}"
	usermod -aG sudo $(MACHINE_USERNAME)

user_copy_do_setup:
	@cp -r /root/do-setup /home/$(MACHINE_USERNAME)
	@chown -R $(MACHINE_USERNAME):$(MACHINE_USERNAME) /home/$(MACHINE_USERNAME)/do-setup
	@chmod -R 755 /home/$(MACHINE_USERNAME)/do-setup

# user_create_ssh_agent_daemon:
# 	@printf '[Unit]\nDescription=SSH authentication agent\n\n[Service]\nExecStart=/usr/bin/ssh-agent -a %%t/ssh-agent.socket -D\nType=simple\n\n[Install]\nWantedBy=default.target\n' \
# 	| sudo tee -a /etc/systemd/user/ssh-agent.service
# 	@systemctl --user enable ssh-agent.service
# 	@systemctl --user start ssh-agent.service
# 	@echo '# Nono - Daemon to start ssh-agent upon login to server' >> ~/.bashrc
# 	@echo 'export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"' >> ~/.bashrc
# 	@exit

php73_install:
	@add-apt-repository ppa:ondrej/php -y
	@apt-get update
	@apt-get install php7.3 -y
	@apt install \
	php7.3-cli \
	php7.3-fpm \
	php7.3-json \
	php7.3-pdo \
	php7.3-mysql \
	php7.3-zip \
	php7.3-gd \
	php7.3-mbstring \
	php7.3-curl \
	php7.3-xml \
	php7.3-bcmath \
	php7.3-json -y
	@sed -i -e 's/php7.2-fpm/php7.3-fpm/g' /etc/nginx/sites-available/digitalocean
	@sudo systemctl restart nginx

# Preseed phpMyAdmin install selections (to skip interactive input)
phpmyadmin_setup:
	echo "phpmyadmin phpmyadmin/internal/skip-preseed boolean true" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/admin-pass password $(PHPMYADMIN_MYSQL_ROOT_PASSWORD)" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/app-pass password $(PHPMYADMIN_PASSWORD)" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/app-password-confirm password $(PHPMYADMIN_PASSWORD)" | debconf-set-selections

phpmyadmin:
	apt update
	apt-get install debconf-utils -y
	@make phpmyadmin_setup
	apt install phpmyadmin -y
	ln -s /usr/share/phpmyadmin /var/www/html/pma

mysql_show:
	@mysql -u root -p -e "${MYSQL_SHOW}"

mysql_down:
	@mysql -u root -p -e "\
	DROP DATABASE $(DB_DATABASE); \
	DROP USER '$(DB_USERNAME)'@'localhost';\
	$(MYSQL_SHOW)\
	FLUSH PRIVILEGES;\
	"

mysql_up:
	@mysql -u root -p -e \
	"CREATE DATABASE $(DB_DATABASE); \
	CREATE USER '$(DB_USERNAME)'@'localhost' IDENTIFIED BY '$(DB_PASSWORD)';\
    ALTER USER '$(DB_USERNAME)'@'localhost' IDENTIFIED BY '$(DB_PASSWORD)';\
    GRANT ALL PRIVILEGES ON *.* TO '$(DB_USERNAME)'@'localhost';\
	$(MYSQL_SHOW)\
	FLUSH PRIVILEGES;\
	"

www_html_index:
	@rm /var/www/html/index.html
	@echo "<html lang='es'><head><meta charset='utf-8'><title>Nono.MA</title></head>\
	<style>* { font-family: system-ui, sans-serif; }</style>\
	Hi. I'm <a href='https://nono.ma/about' target='_blank'>Nono Martínez Alonso</a>.<br/><br/> \
	Look me up on <a href='https://www.google.com/search?q=%22Nono+Martinez+Alonso%22' target='_blank'>Google</a>,<br/> \
	listen to my <a href='https://gettingsimple.com' target='_blank'>podcast</a>,<br/> \
	see my <a href='https://sketch.nono.ma' target='_blank'>sketches</a>,<br/> \
	or read <a href='https://nono.ma' target='_blank'>blog</a>." > /var/www/html/index.html

www_privileges:
	@chown -R $(MACHINE_USERNAME):$(MACHINE_USERNAME) /var/www
	@chmod -R 755 /var/www
	@echo "Granted permissions to $(MACHINE_USERNAME) at /var/www"

################################################
# Switch to {MACHINE_USERNAME}
################################################

root_enter_username:
	@runuser -l $(MACHINE_USERNAME) -c 'cd do-setup'

################################################
# SSH
################################################

ssh_key_create:
	@ssh-keygen -f ~/.ssh/id_rsa

ssh_key_print:
	@echo
	@cat ~/.ssh/id_rsa.pub
	@echo
	@echo "Now add this key to:"
	@echo "- Github · https://github.com/settings/ssh/new"
	@echo "- Bitbucket · https://bitbucket.org/dashboard/overview"
	@echo

ssh_key_add_bash_agent:
	@echo "" >> ~/.bashrc
	@echo "# Nono · Load ssh-agent on startup" >> ~/.bashrc
	@echo 'eval $$(ssh-agent -s)' >> ~/.bashrc
	@echo 'ssh-add' >> ~/.bashrc

################################################
# GIT
################################################

git_user_setup:
	@git config --global user.email $(GIT_EMAIL)
	@git config --global user.name "$(GIT_FULLNAME)"

git_swap_https_to_ssh:
	@git remote set-url origin git@github.com:nonoesp/do-setup.git

################################################
# NGINX & CERTBOT
################################################

domain:
	@make nginx_domain
	@make certbot_domain

subdomain:
	@make nginx_domain
	@make certbot_subdomain

nginx_domain:
	@echo ""
	@echo "## NGINX DOMAIN SETUP ##"
	@read -p "Domain (e.g. example.com): " DOMAIN; \
	DOMAIN="$$DOMAIN"; \
    echo $$DOMAIN ; \
	cat ./templates/nginx-digitalocean.template | sed -e s/{{domain}}/$$DOMAIN/g > /etc/nginx/sites-available/$$DOMAIN ; \
	rm /etc/nginx/sites-enabled/$$DOMAIN || true ; \
	ln -s /etc/nginx/sites-available/$$DOMAIN /etc/nginx/sites-enabled ; \
	nginx -t ; \
	systemctl reload nginx ; \
	mkdir /var/www/$$DOMAIN || true ; \
	chown -R $(MACHINE_USERNAME):$(MACHINE_USERNAME) /var/www/$$DOMAIN ; \
	chmod -R 755 /var/www/$$DOMAIN ; \
	echo "" ; \
	echo "Succesfully created site folder at /var/www/$$DOMAIN" ; \
	echo "Web root is at /var/www/$$DOMAIN/public" ; \
	echo ""

nginx_domain_down:
	@echo ""
	@echo "## NGINX REMOVE DOMAIN SETUP ##"
	@read -p "Domain (e.g. example.com): " DOMAIN; \
	DOMAIN="$$DOMAIN"; \
    echo $$DOMAIN ; \
	rm /etc/nginx/sites-available/$$DOMAIN || true ; \
	rm /etc/nginx/sites-enabled/$$DOMAIN || true ; \
	nginx -t ; \
	systemctl reload nginx ; \
	echo "" ; \
	echo "Succesfully remove $$DOMAIN from nginx." ; \
	echo ""

certbot_domain:
	@echo ""
	@echo "## CERTBOT DOMAIN SETUP - Let\'s Encrypt ##"
	@read -p "Domain (e.g. example.com): " DOMAIN; \
	DOMAIN="$$DOMAIN"; \
    certbot --nginx -d $$DOMAIN -d www.$$DOMAIN ;

certbot_subdomain:
	@echo ""
	@echo "## CERTBOT SUBDOMAIN SETUP - Let\'s Encrypt ##"
	@read -p "Subdomain (e.g. example.com): " DOMAIN; \
	DOMAIN="$$DOMAIN"; \
    certbot --nginx -d $$DOMAIN ;

################################################
# SWAP SPACE & NGINX UPLOAD SIZE
# Lets us run memory-heavy commands
# (e.g. composer update)
################################################

swap_space_increase:
	/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
	/sbin/mkswap /var/swap.1
	/sbin/swapon /var/swap.1

nginx_setup_client_max_body_size:
	@sed -i 's/client_max_body_size/#client_max_body_size/g' \
	/etc/nginx/nginx.conf
	@sed -i 's/http {/http { \n# Nono · increase body size\nclient_max_body_size 64m;/g' \
	/etc/nginx/nginx.conf
	@systemctl restart nginx

################################################
# PHP · composer
################################################

php_setup:
	@sudo apt install unzip -y
	@make composer_install

composer_install:
	@cd ~
	@curl -sS https://getcomposer.org/installer -o composer-setup.php
	# @php -r "if (hash_file('SHA384', 'composer-setup.php') === '$HASH') \
	# { echo 'Installer verified'; } else { \
	# echo 'Installer corrupt'; unlink('composer-setup.php'); \
	# } echo PHP_EOL;"
	@sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
	@composer

folio_clone:
	@git clone https://github.com/nonoesp/laravel-folio /var/www/laravel-folio

folio_setup:
	@echo ""
	@echo "## FOLIO SETUP ##"
	@read -p "Path to app (e.g. /var/www/sample.com): " FOLIOPATH; \
	FOLIOPATH="$$FOLIOPATH"; \
	make folio_setup_env_auto laravel_env_path=$$FOLIOPATH; \
	sudo chown -R $(MACHINE_USERNAME):www-data $$FOLIOPATH/storage; \
	sudo chown -R $(MACHINE_USERNAME):www-data $$FOLIOPATH/bootstrap/cache; \
	sudo chmod -R 775 $$FOLIOPATH/storage; \
	sudo chmod -R 775 $$FOLIOPATH/bootstrap/cache; \
	mkdir $$FOLIOPATH/public/img || true; \
	mkdir $$FOLIOPATH/storage/app/public/uploads || true; \
	sudo chmod -R 777 $$FOLIOPATH/storage/app/public/uploads; \
	sudo ln -s $$FOLIOPATH/storage/app/public/uploads $$FOLIOPATH/public/img/u; \
	cd $$FOLIOPATH; \
	composer install --no-dev; \
	php artisan key:generate; \
	php artisan migrate; \
	cd ~/do-setup; \
	echo "Done setting up $$FOLIOPATH"
	
folio_setup_env_prompt:
	@read -p "Path to app (e.g. /var/www/sample.com): " FOLIOPATH; \
	FOLIOPATH="$$FOLIOPATH"; \
	make folio_setup_env_auto laravel_env_path=$$FOLIOPATH;

folio_setup_env_auto:
	@clear
	@echo ""
	@echo "##########################################"
	@echo "## Folio setup .env"
	@echo "##########################################"
	@test -f $(laravel_env_path)/.env && \
	(\
	echo "## Environment file exists (at $(laravel_env_path)/.env )." \
	) \
	|| \
	( \
	echo "## Environment file does not exist (at $(laravel_env_path)/.env )." && \
	echo "## Creating.." && \
	cp ./templates/laravel-env.template $(laravel_env_path)/.env \
	)
	@sed -i -e "s/DB_DATABASE=.*/DB_DATABASE=$(DB_DATABASE)/g" $(laravel_env_path)/.env
	@sed -i -e "s/DB_USERNAME=.*/DB_USERNAME=$(DB_USERNAME)/g" $(laravel_env_path)/.env
	@sed -i -e "s/DB_PASSWORD=.*/DB_PASSWORD=$(DB_PASSWORD)/g" $(laravel_env_path)/.env
	@echo "##########################################"
	@echo ""
