nginx:
	@make nginx_domain

nginx_remove:
	@make nginx_domain_remove

nginx_domain_remove:
	@echo ""
	@echo "## REMOVE NGINX DOMAIN ##"
	@read -p "Domain (e.g. example.com): " DOMAIN; \
	DOMAIN="$$DOMAIN" ; \
	make nginx_domain_remove_auto domain=$$DOMAIN

nginx_domain_remove_auto:
	@rm /usr/local/etc/nginx/sites-enabled/$(domain) || true
	@rm /usr/local/etc/nginx/sites-available/$(domain) || true
	@nginx -t
	@brew services restart nginx

nginx_domain:
	@make nginx_domain_prompt

nginx_domain_prompt:
	@echo ""
	@echo "## NGINX DOMAIN SETUP ##"
	@read -p "Domain (e.g. example.com): " DOMAIN; \
	DOMAIN="$$DOMAIN"; \
	read -p "Site path (e.g. /usr/local/var/www/example.com): " ROOT; \
	ROOT="$$ROOT"; \
	make nginx_domain_auto domain=$$DOMAIN root=$$ROOT
	
nginx_domain_auto:
	$(eval escapedRoot = `echo $(root) | sed 's/\//{{slash}}/g'`)
	@cp ../templates/nginx-macos.template /usr/local/etc/nginx/sites-available/$(domain)
	@sed -i -e s/{{domain}}/$(domain)/g /usr/local/etc/nginx/sites-available/$(domain)
	@sed -i -e s/{{root}}/${escapedRoot}/g /usr/local/etc/nginx/sites-available/$(domain)
	@sed -i -e 's/{{slash}}/\//g' /usr/local/etc/nginx/sites-available/$(domain)
	@rm /usr/local/etc/nginx/sites-available/$(domain)-e || true
	@rm /usr/local/etc/nginx/sites-enabled/$(domain) || true
	@ln -s /usr/local/etc/nginx/sites-available/$(domain) /usr/local/etc/nginx/sites-enabled
	@nginx -t
	@brew services restart nginx
	@mkdir $(root) || true
	@echo ""
	@echo "Succesfully created site folder at $(root)"
	@echo "Web root is at $(root)"
	@echo ""

nginx_list:
	@ls /usr/local/etc/nginx/sites-enabled