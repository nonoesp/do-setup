# Config
username=nono
db_name=folio_sample
db_user=folio_user_sample
db_password=p
phpmyadmin_password=pp
phpmyadmin_mysql_root_password=ppp

# Util
mysql_show=SHOW DATABASES;SELECT user FROM mysql.user;

setup:
	@make user
	@make phpmyadmin
	@make mysql_up
	@make www_html_index
	@make www_privileges

user:
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