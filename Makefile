# Config
username=nono
db_name=folio_sample
db_user=folio_user_sample
db_password=p
phpmyadmin_password=pp
phpmyadmin_mysql_root_password=ppp

################################################
# Automation for root account
################################################

# Util
mysql_show=SHOW DATABASES;SELECT user FROM mysql.user;

setup:
	@make setup_root_account

setup_user:
	@make setup_user_account

# To be run as root
setup_root_account:
	@make git_user_setup
	@make git_swap_https_to_ssh
	@make user_create
	@make user_copy_do_setup
	@make phpmyadmin
	@make mysql_up
	@make www_html_index
	@make www_privileges
	@make ssh_key_create
	@make ssh_key_print
	@make ssh_key_add_bash_agent
	@make swap_space_increase
	## TODO - install npm
	## TODO - add swap space for composer update

# To be run as {username}
setup_user_account:
	@make git_user_setup
	@make git_swap_https_to_ssh
	@make ssh_key_create
	@make ssh_key_print
	@make ssh_key_add_bash_agent
	@make php_setup

user_create:
	@echo "Creating user ${username}.."
	adduser $(username)
	@echo "Providing sudo priveleges to ${username}"
	usermod -aG sudo $(username)

user_copy_do_setup:
	@cp -r /root/do-setup /home/$(username)
	@chown -R $(username):$(username) /home/$(username)/do-setup
	@chmod -R 755 /home/$(username)/do-setup

# user_create_ssh_agent_daemon:
# 	@printf '[Unit]\nDescription=SSH authentication agent\n\n[Service]\nExecStart=/usr/bin/ssh-agent -a %%t/ssh-agent.socket -D\nType=simple\n\n[Install]\nWantedBy=default.target\n' \
# 	| sudo tee -a /etc/systemd/user/ssh-agent.service
# 	@systemctl --user enable ssh-agent.service
# 	@systemctl --user start ssh-agent.service
# 	@echo '# Nono - Daemon to start ssh-agent upon login to server' >> ~/.bashrc
# 	@echo 'export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"' >> ~/.bashrc
# 	@exit

# Preseed phpMyAdmin install selections (to skip interactive input)
phpmyadmin_setup:
	echo "phpmyadmin phpmyadmin/internal/skip-preseed boolean true" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/admin-pass password $(phpmyadmin_mysql_root_password)" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/mysql/app-pass password $(phpmyadmin_password)" | debconf-set-selections
	echo "phpmyadmin phpmyadmin/app-password-confirm password $(phpmyadmin_password)" | debconf-set-selections

phpmyadmin:
	apt update
	apt-get install debconf-utils -y
	@make phpmyadmin_setup
	apt install phpmyadmin -y
	ln -s /usr/share/phpmyadmin /var/www/html/pma

mysql_show:
	@mysql -u root -p -e "${mysql_show}"

mysql_down:
	@mysql -u root -p -e "\
	DROP DATABASE $(db_name); \
	DROP USER '$(db_user)'@'localhost';\
	$(mysql_show)\
	FLUSH PRIVILEGES;\
	"

mysql_up:
	@mysql -u root -p -e \
	"CREATE DATABASE $(db_name); \
	CREATE USER '$(db_user)'@'localhost' IDENTIFIED BY '$(db_password)';\
    ALTER USER '$(db_user)'@'localhost' IDENTIFIED BY '$(db_password)';\
    GRANT ALL PRIVILEGES ON *.* TO '$(db_user)'@'localhost';\
	$(mysql_show)\
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
	@chown -R $(username):$(username) /var/www
	@chmod -R 755 /var/www
	@echo "Granted permissions to $(username) at /var/www"

################################################
# Switch to {username}
################################################

root_enter_username:
	@runuser -l $(username) -c 'cd do-setup'

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
	@git config --global user.email mundowarezweb@gmail.com
	@git config --global user.name "Nono Martínez Alonso"

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
	cat nginx.template | sed -e s/example.com/$$DOMAIN/g > /etc/nginx/sites-available/$$DOMAIN ; \
	rm /etc/nginx/sites-enabled/$$DOMAIN || true ; \
	ln -s /etc/nginx/sites-available/$$DOMAIN /etc/nginx/sites-enabled ; \
	nginx -t ; \
	systemctl reload nginx ; \
	mkdir /var/www/$$DOMAIN || true ; \
	chown -R $(username):$(username) /var/www/$$DOMAIN ; \
	chmod -R 755 /var/www/$$DOMAIN ; \
	echo "" ; \
	echo "Succesfully created site folder at /var/www/$$DOMAIN" ; \
	echo "Web root is at /var/www/$$DOMAIN/public" ; \
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
# SWAP SPACE
# Lets us run memory-heavy commands
# (e.g. composer update)
################################################

swap_space_increase:
	/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
	/sbin/mkswap /var/swap.1
	/sbin/swapon /var/swap.1

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
	@read -p "Path to app (e.g. /var/www/sample.com): " PATH; \
	PATH="$$PATH"; \
	echo $$PATH
    # sudo chown -R $(username):www-data $$PATH/storage; \
    # sudo chown -R $(username):www-data $$PATH/boostrap/cache; \
	# sudo chmod -R 775 $$PATH/storage ; \
	# sudo chmod -R 775 $$PATH/boostrap/cache
	echo "Done setting up $$PATH"