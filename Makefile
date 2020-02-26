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

# To be run as root
setup_root_account:
	@make user_create
	@make phpmyadmin
	@make mysql_up
	@make www_html_index
	@make www_privileges
	@make ssh_key_create
	@make ssh_key_print
	@make ssh_key_add_bash_agent	

# To be run as {username}
setup_user_account:
	@make ssh_key_create
	@make ssh_key_print
	@make ssh_key_add_bash_agent

user_create:
	@echo "Creating user ${username}.."
	adduser $(username)
	@echo "Providing sudo priveleges to ${username}"
	usermod -aG sudo $(username)

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
	@runuser -l $(username) -c 'mkdir dir_in_username'

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

# TODO - fix (alias line, in ssh-agent, doesn't work)
ssh_key_add_bash_agent:
	@echo "" >> ~/.bashrc
	@echo "# Nono · Load ssh-agent on startup" >> ~/.bashrc
	@echo "alias sha=\"eval '$(echo \'ssh-agent -s\')' && ssh-add ~/.ssh/id_rsa\"" >> ~/.bashrc

################################################
# NGINX
################################################

nginx_domain:
	@read -p "Domain (e.g. example.com): " DOMAIN; \
	DOMAIN="$$DOMAIN"; \
    echo $$DOMAIN ; \
	cat nginx.template | sed -e s/example.com/$$DOMAIN/g > /etc/nginx/sites-available/$$DOMAIN ; \
	rm /etc/nginx/sites-enabled/$$DOMAIN ; \
	ln -s /etc/nginx/sites-available/$$DOMAIN /etc/nginx/sites-enabled
	@nginx -t
	@systemctl reload nginx