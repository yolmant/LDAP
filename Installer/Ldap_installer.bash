#!/bin/bash
Menu=$(whiptail --title "LDAP" --menu "Choose an option" 15 60 5 \
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
				sleep 1
 			done 
		} | whiptail --gauge "Please wait while installing" 6 60 0
	
		whiptail --title "LDAP Installer" --msgbox "Packages installed. press ok to continue" 10 60
	
		systemctl enable slapd.service
        	systemctl start slapd.service
        	systemctl enable httpd.service
        	systemctl start httpd.service

        	sed -i 's,Require local,#Require local\n    Require all granted,g' /etc/httpd/conf.d/phpldapadmin.conf

        	systemctl restart httpd.service

        	setsebool -P httpd_can_connect_ldap on
      
		whiptail --title "LDAP Installer" --msgbox "services started and enabled" 10 60

	elif [ $Menu = 2 ]; then
		i="0"
		while [ $i = 0 ] 
		do
			whiptail --title "LDAP configuration" --msgbox "this configuration will automatically setup in the LDAP server and any ldif file will be stored in the next directory ~/tmp/LDAP_conf" 10 60

			Domain=$(whiptail --title "LDAP configuration" --inputbox "please introduce the domain or distinguished name. for example:" 10 60 dc=example,dc=net 3>&1 1>&2 2>&3)
			option=$?
			if [ $option = 0 ]; then
				RootD=$(whiptail --title "LDAP configuration" --inputbox "please introduce the LDAP account for root. for example:" 10 60 cn=admin,dc=example,dc=net 3>&1 1>&2 2>&3)
				option=$?
				if [ $option = 0 ]; then
					Passwd=$(whiptail --title "LDAP configuration" --passwordbox "please introduce the LDAP root account password. for example:" 10 60 3>&1 1>&2 2>&3)
					option=$?
					if [ $option = 0 ]; then
						
					else
						whiptail --title "LDAP configuration" --msgbox "Program Finished" 10 60
						 break
					fi
				else 
					whiptail --title "LDAP configuration" --msgbox "Program Finished" 10 60
					break
				fi
			else 
				whiptail --title "LDAP configuration" --msgbox "Program Finished" 10 60
				break
			fi
			i="1"
		done
		whiptail --title "LDAP configuration" --msgbox "Program Finished" 10 60
	fi		
else
	echo "Program finished."
fi

