#!/bin/bash

#this shell script will install and allow you to connect as LDAP user

#update the system to add the latest version of the services
apt-get --yes update && apt-get --yes upgrade && apt-get --yes dist-upgrade

#Disable the interaction with the system
export DEBIAN_FRONTEND=noninteractive

#install ldap and authentication client
apt-get --yes install libpam-ldap nscd
unset DEBIAN_FRONTEND

#modify ldap.conf 
sed -i 's,base dc=example\,dc=net,base dc=NTI,dc=local,g' /etc/ldap.conf
sed -i 's,uri ldapi:///,uri ldap://10.128.0.2/,g' /etc/ldap.conf
sed -i 's,rootbinddn cn=manager\,dc=example\,dc=net,#rootbinddn cn=manager\,dc=example\,dc=local,g' /etc/ldap.conf

#modify nsswitch.conf
sed -i 's,passwd:         compat,passwd:     ldap compat,g' /etc/nsswitch.conf 
sed -i 's,group:         compat,passwd:     ldap compat,g' /etc/nsswitch.conf
sed -i 's,shadow:         compat,passwd:     ldap compat,g' /etc/nsswitch.conf
sed -i 's,netgroup:         nis,netgroup:     ldap,g' /etc/nsswitch.conf

#modify common-session file
sed -i '$ a\session required      pam_mkhomedir.so skel=/etc/skel umask=0022' /etc/pam.d/common-session

#restarting the nscd service
/etc/init.d/nscd restart

#to restrict user the administration edit the sudoers file
#commenting the line admin ALL=(ALL) ALL

#to allow the access of the instance with ssh
#comment out the next lines
sed -i 's,PasswordAuthentication no,#PasswordAuthentication no,g' /etc/ssh/sshd_config
sed -i 's,ChallengeResponseAuthentication no,#ChallengeResponseAuthentication no,g' /etc/ssh/sshd_config

#restart the sshd service
systemctl restart sshd.service

#to test the client connect the instance with the ssh command
# ssh <username>@<ipoftheclient>
