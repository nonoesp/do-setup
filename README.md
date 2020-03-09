# do-setup

A set of Makefile automation commands to setup a new Digital Ocean LEMP instance with Nginx.

## Usage

### PART 1: root

- Create a [LEMP droplet](https://cloud.digitalocean.com/marketplace/5ba19755c472e4189b34e04e?i=c8d5e9)
    - `$5/mo`
    - `London` or the closest to your geo-location
    - Add you `SSH keys`
- `ssh root@{ip}` · site at http://{ip}
- `apt install make -y && git clone https://github.com/nonoesp/do-setup && cd do-setup && cp .env.example .env`
- Setup your config values in `.env`
- `make setup`
- `make domain` or `make subdomain` to add Nginx domain or subdomain (A record) configs

### PART 2: user

- `su - {username}`
- `cd do-setup && make setup_user`
- Add SSH key to GitHub
- `make folio_clone`
- Clone or create a Laravel app to `/var/www/{domain}`
- `make folio_setup`
