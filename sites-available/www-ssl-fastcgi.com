# Define path to cache and memory zone. The memory zone should be unique.
# keys_zone=example.com:100m creates the memory zone and sets the maximum size in MBs.
# inactive=60m will remove cached items that haven't been accessed for 60 minutes or more.
fastcgi_cache_path /home/infilimits/www.example.com/cache levels=1:2 keys_zone=www.example.com:100m inactive=60m;

server {
	# Ports to listen on, uncomment one.
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	# Server name to listen for
	server_name www.example.com;

	# Path to website root
	root /home/infilimits/www.example.com/public;

	# Paths to certificate files.
	ssl_certificate /etc/letsencrypt/live/www.example.com/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/www.example.com/privkey.pem;

	# File to be used as index
	index index.php;

	# Overrides logs defined in nginx.conf, allows per site logs.
	access_log /home/infilimits/www.example.com/logs/access.log;
	error_log /home/infilimits/www.example.com/logs/error.log;

	# Default server block rules
	include global/server/defaults.conf;

	# Fastcgi cache rules
	include global/server/fastcgi-cache.conf;

	# SSL rules
	include global/server/ssl.conf;

	location / {
		try_files $uri $uri/ /index.php?$args;
	}

	location ~ \.php$ {
		try_files $uri =404;
		include global/fastcgi-params.conf;

		# Use the php pool defined in the upstream variable.
		# See global/php-pool.conf for definition.
		fastcgi_pass   $upstream;

		# Skip cache based on rules in global/server/fastcgi-cache.conf.
		fastcgi_cache_bypass $skip_cache;
		fastcgi_no_cache $skip_cache;

		# Define memory zone for caching. Should match key_zone in fastcgi_cache_path above.
		fastcgi_cache www.example.com;

		# Define caching time.
		fastcgi_cache_valid 60m;
	}

	# Rewrite robots.txt
	rewrite ^/robots.txt$ /index.php last;

	# Uncomment if using the fastcgi_cache_purge module and Nginx Helper plugin (https://wordpress.org/plugins/nginx-helper/)
	# location ~ /purge(/.*) {
	#	fastcgi_cache_purge www.example.com "$scheme$request_method$host$1";
	# }
}

# Redirect http to https
server {
	listen 80;
	listen [::]:80;
	server_name example.com www.example.com;

	return 301 https://www.example.com$request_uri;
}

# Redirect non-www to www
server {
	listen 443;
	listen [::]:443;
	server_name example.com;

	return 301 https://www.example.com$request_uri;
}
