#!/bin/bash
sudo amazon-linux-extras install nginx1 -y 
sudo amazon-linux-extras install postgresql11 -y
touch /etc/nginx/conf.d/test.conf
cat > /etc/nginx/conf.d/test.conf  <<EOF
server {
    listen 80;

    location / {
        proxy_pass http://${webserver-private-ip};
    }
}
EOF
sudo service nginx start
