#!/bin/bash
#disable the anonymous login
sed -i -e "s/\/\/ \$servers->setValue('login','anon_bind',true);/\$servers->setValue('login','anon_bind',false);/" /etc/phpldapadmin/config.php

#instal SSL
yum install mod_ssl

#create a new directory to store the key
mkdir /etc/ssl/private

#change the permission of the new directory
chmod 700 /etc/ssl/private

#creating the certification and key
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/apache.key -out /etc/ssl/certs/apache.crt
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

#include the detail of the phpldapadmin webside to the port 443
sed -i "57s/.*/Alias \/phpldapadmin \/usr\/share\/phpldapadmin\/htdocs\nAlias \/ldapadmin \/usr\/share\/phpldapadmin\/htdocs\nDocumentRoot \"\/usr\/share\/phpldapadmin\/htdocs\"/" /etc/httpd/conf.d/ssl.conf

#comment out
sed -i -e "s/SSLProtocol all -SSLv2/#SSLProtocol all -SSLv2/" /etc/httpd/conf.d/ssl.conf
sed -i -e "s/SSLCipherSuite HIGH:MEDIUM:\!aNULL:\!MD5:\!SEED:\!IDEA/#SSLCipherSuite HIGH:MEDIUM:\!aNULL:\!MD5:\!SEED:\!IDEA/" /etc/httpd/conf.d/ssl.conf

#include the Update Cypher suit
sh -c 'echo "# Begin copied text
# from https://cipherli.st/
# and https://raymii.org/s/tutorials/Strong_SSL_Security_On_Apache2.html

SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3
SSLHonorCipherOrder On
# Disable preloading HSTS for now.  You can use the commented out header line that includes
# the \"preload\" directive if you understand the implications.
#Header always set Strict-Transport-Security \"max-age=63072000; includeSubdomains; preload\"
Header always set Strict-Transport-Security \"max-age=63072000; includeSubdomains\"
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
# Requires Apache >= 2.4
SSLCompression off
SSLUseStapling on
SSLStaplingCache \"shmcb:logs/stapling-cache(150000)\"
# Requires Apache >= 2.4.11
# SSLSessionTickets Off" >> /etc/httpd/conf.d/ssl.conf'

#Restart the hhtpd service
systemctl restart httpd.service
