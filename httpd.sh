#!/bin/sh
set -e

apt update
apt install -y nginx-light
echo "hello world from $(hostname -f)" > /var/www/html/index.html
systemctl enable nginx-light
systemctl start nginx-light

# yum -t -y install httpd
# echo "hello world from $(hostname -f)" > /var/www/html/index.html
# systemctl enable httpd
# systemctl start httpd