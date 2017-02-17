#!/bin/bash
#this shell script will install and configure LDAP
#remember that all configuration will be preset with my domains and user

#installing all packages
yum -y install openldap-servers openldap-clients
yum -y install httpd epel-release 
yum -y install phpldapadmin

#enabling all services
systemctl enable slapd.service
systemctl start slapd.service
systemctl enable httpd.service
systemctl start httpd.service

#modify the access in phpldapadmin configuration
sed -i 's,Require local,#Require local\n    Require all granted,g' /etc/httpd/conf.d/phpldapadmin.conf
sed -i -e "397s/.*/\$servers->setValue(\'login\'\,\'attr\'\,\'dn\');/" /etc/phpldapadmin/config.php
sed -i  -e "398s/.*/\/\/ \$servers->setValue(\'login\'\,\'attr\'\,\'uid\');/" /etc/phpldapadmin/config.php

#restarting HTTP service
systemctl restart httpd.service

#notify the system
setsebool -P httpd_can_connect_ldap on

#creating a directory to store .ldif files
mkdir ~/LDAP_config

#creatin a SSHA password for LDAP root
password=12345
passw=$(slappasswd -s $password -h {SSHA})

#creating .ldif files
sh -c 'cat > ~/LDAP_config/db.ldif' << EF
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=NTI,dc=local

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=admin,dc=NTI,dc=local

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $passw
EF

sh -c 'cat > ~/LDAP_config/monitor.ldif' << EF
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external, cn=auth" read by dn.base="cn=admin,dc=NTI,dc=local" read by * none
EF

#creating a certification file
sh -c 'cat > ~/LDAP_config/certs.ldif' << EF
dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/NTIcert.pem

dn: cn=config
changetype: modify
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/NTIkey.pem
EF

sh -c 'cat > ~/LDAP_config/base.ldif' << EF
dn: dc=NTI,dc=local
dc: NTI
objectClass: top
objectClass: domain

dn: cn=admin,dc=NTI,dc=local
objectClass: organizationalRole
cn: admin
description: LDAP Manager

dn: ou=ITPeople,dc=NTI,dc=local
objectClass: organizationalUnit
ou: ITPeople

dn: ou=ITGroup,dc=NTI,dc=local
objectClass: organizationalUnit
ou: ITGroup
EF

#creating LDAP certificate
openssl req -new -x509 -nodes -out /etc/openldap/certs/NTIcert.pem -keyout /etc/openldap/certs/NTIkey.pem -days 365 -subj "/C=US/ST=WA/L=Seattle/O=ITcor/OU=ITinfraestructure/CN=server.NTI.local"

#change the permissions to LDAP
chown -R ldap:ldap /etc/openldap/certs/*.pem

#copy the sample database configuration
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown ldap:ldap /var/lib/ldap/*

#set up LDAP server
ldapmodify -Y EXTERNAL  -H ldapi:/// -f ~/LDAP_config/db.ldif
ldapmodify -Y EXTERNAL  -H ldapi:/// -f ~/LDAP_config/monitor.ldif
ldapmodify -Y EXTERNAL  -H ldapi:/// -f ~/LDAP_config/certs.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif 
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
ldapadd -x -w $password -D "cn=admin,dc=NTI,dc=local" -f ~/LDAP_config/base.ldif

#verify the configuration
slaptest -u
