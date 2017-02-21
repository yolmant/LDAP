#!/bin/bash
{
	for ((i = 0 ; i <= 100 ; i+=20)); do
        	if [ $i = 20 ]; then
			apt-get --yes update
		elif [ $i = 40 ]; then
			apt-get --yes upgrade
		elif [ $i = 60 ]; then
			apt-get --yes dist-upgrade
		elif [ $i = 80 ]; then
			export DEBIAN_FRONTEND=noninteractive
		elif [ $i = 100 ]; then
			apt-get --yes install libpam-ldap ncsd
			unset DEBIAN_FRONTEND
		fi
		echo $i
		sleep 1
 	done 	
} | whiptail --gauge "Please wait while installing" 6 60 0

Domain=$(whiptail --title "LDAP client" --inputbox "introduce the LDAP domain. for example:" 10 60 dc=example,dc=net 3>&1 1>&2 2>&3)

Ips=$(whiptail --title "LDAP client" --inputbox "introduce the server IP:" 10 60 3>&1 1>&2 2>&3)

{
	#modify ldap.conf 
	sed -i "s/base dc=example,dc=net/base $Domain/" /etc/ldap.conf
	sed -i "s/uri ldapi:\/\/\//uri ldap:\/\/$Ips\//" /etc/ldap.conf
	sed -i 's,rootbinddn cn=manager\,dc=example\,dc=net,#rootbinddn cn=manager\,dc=example\,dc=net,g' /etc/ldap.conf

	#modify nsswitch.conf	
	sed -i 's,passwd:         compat,passwd:     ldap compat,g' /etc/nsswitch.conf 
	sed -i 's,group:          compat,group:      ldap compat,g' /etc/nsswitch.conf
	sed -i 's,shadow:         compat,shadow:     ldap compat,g' /etc/nsswitch.conf
	sed -i 's,netgroup:       nis,netgroup:       ldap,g' /etc/nsswitch.conf

	#modify common-session file
	sed -i '$ a\session required      pam_mkhomedir.so skel=/etc/skel umask=0022' /etc/pam.d/common-session
	
	#restarting the nscd service
	/etc/init.d/nscd restart
} | whiptail --title "LDAP client" --msgbox "Installing LDAP configuration" 10 60

{
	#to allow the access of the instance with ssh
	#comment out the next lines
	sed -i 's,PasswordAuthentication no,#PasswordAuthentication no,g' /etc/ssh/sshd_config
	sed -i 's,ChallengeResponseAuthentication no,#ChallengeResponseAuthentication no,g' /etc/ssh/sshd_config

	#restart the sshd service
	systemctl restart sshd.service
} | whiptail --title "LDAP client" --msgbox "Configuring the SSH access" 10 60

whiptail --title "LDAP clien" --msgbox "LDAP client installed" 10 60
