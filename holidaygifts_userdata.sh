#!/bin/bash

sudo su

export DEBIAN_FRONTEND=non-interactive

apt-get update && apt-get upgrade -y

apt-get install apache2 git -y

systemctl enable apache2
systemctl start apache2

cd ..
cd ..
cd var
cd www

git clone https://github.com/samcolon/LUITProject19.git

cp -R /var/www/LUITProject19/HolidayGiftsWebsite/* /var/www/html/