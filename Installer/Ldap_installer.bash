#!/bin/bash
Menu=$(whiptail --title "LDAP Installer" --menu "Choose an option" 15 60 5 \
"1" "Install LDAP packages" \
"2" "configure LDAP server" \
"3" "create groups" \
"4" "create users" \
"5" "Uninstall LDAP" 3>&1 1>&2 2>&3)

exitstatus=$?

if [ $exitstatus = 0 ]; then
    if [ $Menu = 1 ]; then
	{
    		for ((i = 0 ; i <= 120 ; i+=20)); do
        		if [ $i = 20 ]; then
				yum -y install openldap-servers
			elif [ $i = 40 ]; then
				yum -y install openldap-clients
			elif [ $i = 60 ]; then
				yum -y install httpd
			elif [ $i = 80 ]; then
				yum -y install epel-release
			elif [ $i = 100 ]; then
				yum -y install phpldapadmin
			fi
			echo $i
 		done 
	} | whiptail --gauge "Please wait while installing" 6 60 0
	fi
	whiptail --title "LDAP Installer" --msgbox "Packages installed. press ok to continue" 10 60

else
    echo "Program finished."
fi

