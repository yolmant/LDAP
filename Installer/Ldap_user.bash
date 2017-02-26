#!/bin/bash
#this script will create a Ldap user in the server
#create the user in the server
useradd ldapuser1

#remember that the directory LDAP_config should have been created in home
mkdir ~/LDAP_config
admpass=12345

#creating a SSHA password
password=123456
passw=$(slappasswd -s $password -h {SSHA})

#creating ldif files for group and users
sh -c 'cat > ~/LDAP_config/groups.ldif' << EF
dn: cn=Server,ou=ITGroup,dc=NTI,dc=local
cn: Server
gidnumber: 500
objectclass: posixGroup
objectclass: top
EF

sh -c 'cat > ~/LDAP_config/users.ldif' << EF
dn: cn=ldapuser1,ou=ITPeople,dc=NTI,dc=local
cn: ldapuser1
gidnumber: 500
givenname: ldapuser
homedirectory: /home/ldapuser1
objectclass: inetOrgPerson
objectclass: posixAccount
objectclass: top
sn: 1
uid: ldapuser1
uidnumber: 1000
userpassword: $passw
EF

ldapadd -x -w $admpass -D cn=admin,dc=NTI,dc=local -f ~/LDAP_config/groups.ldif

ldapadd -x -w $admpass -D cn=admin,dc=NTI,dc=local -f ~/LDAP_config/users.ldif

firewall-cmd --permanent --add-service=ldap
firewall-cmd --reload
