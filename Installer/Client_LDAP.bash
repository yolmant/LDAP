#!/bin/bash
#this is the multi-tasker. Install and configure the LDAP client
Menu=$(whiptail --title "LDAP" --menu "Choose an option" 15 60 5 \
"1" "Install LDAP packages" \
"2" "configure LDAP client" \
"3" "Uninstall LDAP" 3>&1 1>&2 2>&3)

#check if the user press "ok" or "cancel"
exitstatus=$?

#if the user pressed "ok"
if [ $exitstatus = 0 ]; then
#install package selected
	if [ $Menu = 1 ]; then
		{
			for ((i = 0 ; i <= 100 ; i+=50)); do
				if [ $i = 50 ]; then
					apt-get --yes update && apt-get --yes upgrade && apt-get --yes dist-upgrade
				elif [ $i = 100 ]; then
					export DEBIAN_FRONTEND=noninteractive
				 	apt-get --yes install ldap-auth-client nslcd
					unset DEBIAN_FRONTEND
				fi
				echo $i
				sleep 1
			done 	
		} | whiptail --gauge "Please wait while installing" 6 60 0
	elif [ $Menu = 2 ]; then
		Domain=$(whiptail --title "LDAP client" --inputbox "introduce the LDAP domain. for example:" 10 60 dc=example,dc=net 3>&1 1>&2 2>&3)
		option=$?
		if [ $option = 0 ]; then
			Ips=$(whiptail --title "LDAP client" --inputbox "introduce the server IP:" 10 60 3>&1 1>&2 2>&3)
			option=$?
			if [ $option = 0 ]; then
				{
					#modify ldap.conf 
					sed -i "s/base dc=example,dc=net/base $Domain/" /etc/ldap.conf
					sed -i "s/uri ldapi:\/\/\//uri ldaps:\/\/$Ips\//" /etc/ldap.conf
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
			fi
		fi
	elif [ $Menu = 3 ]; then
		{
			apt-get --yes remove ldap-auth-client nscd
		} | whiptail --title "LDAP client" --msgbox "Package Uninstalled" 10 60
	fi
fi
whiptail --title "LDAP clien" --msgbox "LDAP client installed" 10 60
