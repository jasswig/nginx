#! /bin/bash

exec >> /var/log/user-data.log 2>&1


# https://nginx.org/en/linux_packages.html

yum install -y yum-utils

cat <<EOF > /etc/yum.repos.d/nginx.repo
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/amzn2/2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF

yum update -y

yum install -y nginx # nginx-1.22.1-1.amzn2.ngx.x86_64

systemctl start nginx

systemctl enable nginx

curl localhost

echo "Create custom default.conf in /etc/nginx/conf.d/"

mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default_conf.txt

# Simple default file
cat <<EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _; 
    root /usr/share/nginx/html;

    error_page 404 /404.html;
    error_page 500 501 502 503 504 /50x.html;
}
EOF

cat <<EOF > /usr/share/nginx/html/404.html
<h1>404. Page not found</h1>
EOF

echo "Check configuration"
nginx -t 

systemctl reload nginx
systemctl status nginx

curl localhost
curl localhost/test.html

echo "Another server config...."

cat <<EOF > /etc/nginx/conf.d/example.com.conf
server {
    listen 80;
    server_name www.example.com example.com; 
    root /var/www/example.com/html;
}
EOF

cat <<EOF > /var/www/example.com/html
<h1>Welcom from example.com</h1>
EOF


nginx -t 
systemctl reload nginx
systemctl status nginx

curl --header "Host: example.com" localhost
curl --header "Host: www.example.com" localhost

# https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html

echo "Auth with location..."
yum install -y httpd-tools

htpasswd -b -c /etc/nginx/.htpasswd admin password

cat <<EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _; 
    root /usr/share/nginx/html;

    location = /admin.html {
        auth_basic "Login Required";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }

    error_page 404 /404.html;
    error_page 500 501 502 503 504 /50x.html;
}
EOF

cat <<EOF > /usr/share/nginx/html/admin.html
<h1>Admin Page</h1>
EOF

nginx -t 
systemctl reload nginx
systemctl status nginx

curl -u admin:password localhost/admin.html

# https://nginx.org/en/docs/http/configuring_https_servers.html

echo "Self signed certificates... SSL.. https.."

mkdir /etc/nginx/ssl

openssl req -x509 -newkey rsa:2048 -keyout /etc/nginx/ssl/private.key -out /etc/nginx/ssl/public.pem -days 365 -nodes -subj '/CN=localhost'

cat <<EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    listen 443 ssl;
    server_name _; 
    root /usr/share/nginx/html;

    ssl_certificate /etc/nginx/ssl/public.pem;
    ssl_certificate_key /etc/nginx/ssl/private.key;

    location = /admin.html {
        auth_basic "Login Required";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }

    error_page 404 /404.html;
    error_page 500 501 502 503 504 /50x.html;
}
EOF

nginx -t 
systemctl reload nginx
systemctl status nginx

curl https://localhost
curl -k https://localhost

# https://nginx.org/en/docs/http/ngx_http_rewrite_module.html

cat <<EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    listen 443 ssl;
    server_name _; 
    root /usr/share/nginx/html;

    ssl_certificate /etc/nginx/ssl/public.pem;
    ssl_certificate_key /etc/nginx/ssl/private.key;

    rewrite ^(/.*)\.html(\?.*)?\$ \$1\$2 redirect;
    rewrite ^(.*)/\$ \$1 redirect;

    location / {
            try_files \$uri/index.html \$uri.html \$uri/ \$uri =404;
    }

    location = /admin {
        auth_basic "Login Required";
        auth_basic_user_file /etc/nginx/.htpasswd;
        try_files \$uri/index.html \$uri.html \$uri/ \$uri =404;
    }


    error_page 404 /404.html;
    error_page 500 501 502 503 504 /50x.html;
}
EOF

nginx -t 
systemctl reload nginx
systemctl status nginx

curl https://localhost/admin.html?test=true
curl -u admin:password https://localhost/admin.html?test=true

cat <<EOF > /etc/nginx/conf.d/default.conf
server {
        listen 80 default_server;
        server_name _;
        return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name _; 
    root /usr/share/nginx/html;

    ssl_certificate /etc/nginx/ssl/public.pem;
    ssl_certificate_key /etc/nginx/ssl/private.key;

    rewrite ^(/.*)\.html(\?.*)?\$ \$1\$2 redirect;
    rewrite ^(.*)/\$ \$1 redirect;

    location / {
            try_files \$uri/index.html \$uri.html \$uri/ \$uri =404;
    }

    location = /admin {
        auth_basic "Login Required";
        auth_basic_user_file /etc/nginx/.htpasswd;
        try_files \$uri/index.html \$uri.html \$uri/ \$uri =404;
    }



    error_page 404 /404.html;
    error_page 500 501 502 503 504 /50x.html;
}
EOF

nginx -t 
systemctl reload nginx
systemctl status nginx

nginx -V
nginx -V 2>&1 | tr -- - '\n\' | grep _module

# Dynamic modules
yum groupinstall -y 'Development tools'
yum install -y geoip-devel libcurl-devel libxml2-devel libgb-devel openssl-devel libxslt-devel lmdb-devel pcre-devel pcre2-devel perl-ExtUtils-Embed yajl-devel zlib-devel
cd /opt/
git clone --depth 1 -b v3/master https://github.com/SpiderLabs/ModSecurity.git
cd ModSecurity
git submodule init
git submodule update
./build.sh
echo $?

./configure
make
make install

cd /opt/
git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

wget http://nginx.org/download/nginx-1.22.1.tar.gz
tar zxvf nginx-1.22.1.tar.gz
cd nginx-1.22.1
./configure --with-compat --add-dynamic-module=../ModSecurity-nginx --add-module=../ModSecurity-nginx
make modules
cp /opt/nginx-1.22.1/objs/ngx_http_modsecurity_module.so /etc/nginx/modules/

cd /etc/nginx
cp nginx.conf nginx_conf.txt

cat <<EOF > /etc/nginx/nginx.conf
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

# Load modSecurity
load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;

events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
EOF

mkdir /etc/nginx/modsecurity
cp /opt/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsecurity/modsecurity.conf
cp /opt/ModSecurity/unicode.mapping /etc/nginx/modsecurity/unicode.mapping

cat <<EOF > /etc/nginx/conf.d/default.conf
server {
        listen 80 default_server;
        server_name _;
        return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name _; 
    root /usr/share/nginx/html;

    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsecurity/modsecurity.conf;

    ssl_certificate /etc/nginx/ssl/public.pem;
    ssl_certificate_key /etc/nginx/ssl/private.key;

    rewrite ^(/.*)\.html(\?.*)?\$ \$1\$2 redirect;
    rewrite ^(.*)/\$ \$1 redirect;

    location / {
            try_files \$uri/index.html \$uri.html \$uri/ \$uri =404;
    }

    location = /admin {
        auth_basic "Login Required";
        auth_basic_user_file /etc/nginx/.htpasswd;
        try_files \$uri/index.html \$uri.html \$uri/ \$uri =404;
    }



    error_page 404 /404.html;
    error_page 500 501 502 503 504 /50x.html;
}
EOF

nginx -t 
systemctl reload nginx
systemctl status nginx

echo "Done.."