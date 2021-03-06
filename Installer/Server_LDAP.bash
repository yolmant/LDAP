#!/bin/bash
#creatring a loop for the programm
lp=0
while [ $lp = 0 ] 
do
	#this is the multi-tasker. Install and configure the LDAP server
	Menu=$(whiptail --title "LDAP" --menu "Choose an option" 15 60 5 \
	"1" "Install LDAP packages" \
	"2" "Configure LDAP server" \
	"3" "Create groups" \
	"4" "Create users" \
	"5" "Delete Group" \
	"6" "Delete user" \
	"7" "Uninstall LDAP" 3>&1 1>&2 2>&3)

	#check if the user press "ok" or "cancel"
	exitstatus=$?

	#if the user pressed "ok"
	if [ $exitstatus = 0 ]; then
	#install package selected
		if [ $Menu = 1 ]; then
			{
				#a Bar loading that charge from 0% to 100% by 20%
				for ((i = 0 ; i <= 100 ; i+=20)); do
					if [ $i = 20 ]; then
						#install the LDAP server tools
						yum -y install openldap-servers
					elif [ $i = 40 ]; then
						#install the LDAp client tools
						yum -y install openldap-clients
					elif [ $i = 60 ]; then
						#install the apache server
						yum -y install httpd
					elif [ $i = 80 ]; then
						#install the EPEL package
						yum -y install epel-release
					elif [ $i = 100 ]; then
						#Install the PHP LDAP package
						yum -y install phpldapadmin
						#instal SSL
						yum -y install mod_ssl
					fi
					echo $i
					sleep 1
				done 
			#show a dialog box of the bar changing
			} | whiptail --gauge "Please wait while installing" 6 60 0

			#dialog box
			whiptail --title "LDAP Installer" --msgbox "Packages installed. press ok to continue" 10 60
			{	
				systemctl enable slapd.service
				systemctl start slapd.service
				systemctl enable httpd.service
				systemctl start httpd.service
				firewall-cmd --permanent --add-service=ldap
				firewall-cmd --reload

			#dialog box while the services are enabling and starting
			} | whiptail --title "LDAP Installer" --msgbox "enabling and starting services" 10 60

			{
				#modify the file phpldapadmin to permit the connection troughout the website
				sed -i 's,Require local,#Require local\n    Require all granted,g' /etc/httpd/conf.d/phpldapadmin.conf
				sed -i -e "397s/.*/\$servers->setValue(\'login\'\,\'attr\'\,\'dn\');/" /etc/phpldapadmin/config.php
				sed -i  -e "398s/.*/\/\/ \$servers->setValue(\'login\'\,\'attr\'\,\'uid\');/" /etc/phpldapadmin/config.php
				sed -i -e "s/\/\/ \$servers->setValue('login','anon_bind',true);/\$servers->setValue('login','anon_bind',false);/" /etc/phpldapadmin/config.php
				
				#configuring Ldap secure
				sed -i -e "s/SLAPD_URLS=\"ldapi:\/\/\/ ldap:\/\/\/\"/SLAPD_URLS=\"ldapi:\/\/\/ ldap:\/\/\/ ldaps:\/\/\/\"/" /etc/sysconfig/slapd
				
				#Restart Ldap service
				systemctl restart slapd.service
				#Restart the hhtpd service
				systemctl restart httpd.service
				#tell Linux what is going on
				setsebool -P httpd_can_connect_ldap on
				
			#dialog box
			} | whiptail --title "LDAP Installer" --msgbox "services started and enabled" 10 60

		#configuration of LDAP server
		elif [ $Menu = 2 ]; then 
			#create the directory where the ldif files will be stored
			mkdir /tmp/LDAP.cfg
			#dialog box
			whiptail --title "LDAP configuration" --msgbox "this configuration will automatically setup in the LDAP server and any ldif file will be stored in the next directory /tmp/LDAP.cfg" 10 60
				#name your server 
				Sname=$(whiptail --title "LDAP configuration" --inputbox "What would be the name of your LDAP server" 10 60 3>&1 1>&2 2>&3)
				#set in the name
				sed -i -e "s/\$servers->setValue('server','name','Local LDAP Server');/\$servers->setValue('server','name',\'$Sname LDAP Server\');/" /etc/phpldapadmin/config.php
				#dialog box asking for the domain
				Domain=$(whiptail --title "LDAP configuration" --inputbox "please introduce the domain or distinguished name. for example:" 10 60 dc=example,dc=net 3>&1 1>&2 2>&3)
				option=$?
				Do=$(echo $Domain | awk -F[=,] '{print $2}')
				#if the user pressed "ok"
				if [ $option = 0 ]; then
					#dialog box asking for the domain of the root
					RootD=$(whiptail --title "LDAP configuration" --inputbox "please introduce the LDAP account for root. for example:" 10 60 cn=admin,dc=example,dc=net 3>&1 1>&2 2>&3)
					option=$?
					RD=$(echo $RootD | awk -F[=,] '{print $2}')
					#user pressed "ok"
					if [ $option = 0 ]; then
						#dialog box asking for the password of the administrator
						Passwd=$(whiptail --title "LDAP configuration" --passwordbox "please introduce the LDAP root account password:" 10 60 3>&1 1>&2 2>&3)
						Passw=$(slappasswd -s $Passwd -h {SSHA})
						option=$?
						#user pressed "ok"
						if [ $option = 0 ]; then
							{
								#create a ldif file with the configuration of the administrator
								sh -c 'cat > /tmp/LDAP.cfg/db.ldif' << EF
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: $Domain

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: $RootD

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $Passw
EF
								#ldif file allowing the access of the administrator
								sh -c 'cat > /tmp/LDAP.cfg/monitor.ldif' << EF
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external, cn=auth" read by dn.base="$RootD" read by * none
EF

								#creating a certification ldif file
								sh -c 'cat > /tmp/LDAP.cfg/certs.ldif' << EF
dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/LDAPcert.pem

dn: cn=config
changetype: modify
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/LDAPkey.pem
EF
								#creating a ldif file with the base configuration
								sh -c 'cat > /tmp/LDAP.cfg/base.ldif' << EF
dn: $Domain
dc: $Do
objectClass: top
objectClass: domain

dn: $RootD
objectClass: organizationalRole
cn: $RD
description: LDAP Manager

dn: ou=People,$Domain
objectClass: organizationalUnit
ou: People

dn: ou=Group,$Domain
objectClass: organizationalUnit
ou: Group
EF
							#dialog box
							} | whiptail --title "LDAP configuration" --msgbox "creating file. wait a minute" 10 60

							#asking the user information to create the LDAP certification 
							#country
							Co=$(whiptail --title "LDAP configuration" --inputbox "this will create the LDAP certification for your server.\

	please introduce the two initial of the country. for example:" 10 60 US 3>&1 1>&2 2>&3)
							#state
							St=$(whiptail --title "LDAP configuration" --inputbox "please introduce the two initial of the State. for example:" 10 60 WA 3>&1 1>&2 2>&3)
							#city
							ci=$(whiptail --title "LDAP configuration" --inputbox "please introduce the city. for example:" 10 60 Seattle 3>&1 1>&2 2>&3)
							#Organization
							Org=$(whiptail --title "LDAP configuration" --inputbox "please introduce the name of the Organization. for example:" 10 60 ITcorp 3>&1 1>&2 2>&3)
							#Organization Unit
							O=$(whiptail --title "LDAP configuration" --inputbox "please introduce the Organizational Unit. for example:" 10 60 ITinfra 3>&1 1>&2 2>&3)
							#Common Name
							Ca=$(whiptail --title "LDAP configuration" --inputbox "please introduce the Common Name. for example:" 10 60 server.NTI.local 3>&1 1>&2 2>&3)

							{
								#creating the key and certification
								openssl req -new -x509 -nodes -out /etc/openldap/certs/LDAPcert.pem -keyout /etc/openldap/certs/LDAPkey.pem -days 365 -subj "/C=$Co/ST=$St/L=$ci/O=$Org/OU=$O/CN=$Ca"
								#changing the permitions
								chown -R ldap:ldap /etc/openldap/certs/*.pem	
							#dialog box
							} | whiptail --title "LDAP configuration" --msgbox "certifications created" 10 60
					
							#copy the schemas to the Ldap directory
							cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
							
							#changing the permitions
							chown ldap:ldap /var/lib/ldap/*
							
							#create a new directory to store the key
							mkdir /etc/ssl/private

							#change the permission of the new directory
							chmod 700 /etc/ssl/private
			
							{
								#a Bar loading that charge from 0% to 100% by 20%
								for ((i = 0 ; i <= 100 ; i+=20)); do
									if [ $i = 20 ]; then
										#creating the certification and key
										openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/apache.key -out /etc/ssl/certs/apache.crt -subj "/C=$Co/ST=$St/L=$ci/O=$Org/OU=$O/CN=$Ca"
										openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
									elif [ $i = 40 ]; then
										#include the detail of the phpldapadmin webside to the port 443
										sed -i "57s/.*/Alias \/phpldapadmin \/usr\/share\/phpldapadmin\/htdocs\nAlias \/ldapadmin \/usr\/share\/phpldapadmin\/htdocs\nDocumentRoot \"\/usr\/share\/phpldapadmin\/htdocs\"/" /etc/httpd/conf.d/ssl.conf
									elif [ $i = 60 ]; then
										#comment out and replace the certification and key
										sed -i -e "s/SSLProtocol all -SSLv2/#SSLProtocol all -SSLv2/" /etc/httpd/conf.d/ssl.conf
										sed -i -e "s/SSLCipherSuite HIGH:MEDIUM:\!aNULL:\!MD5:\!SEED:\!IDEA/#SSLCipherSuite HIGH:MEDIUM:\!aNULL:\!MD5:\!SEED:\!IDEA/" /etc/httpd/conf.d/ssl.conf
										sed -i -e "s/SSLCertificateFile \/etc\/pki\/tls\/certs\/localhost.crt/SSLCertificateFile \/etc\/ssl\/certs\/apache.crt/" /etc/httpd/conf.d/ssl.conf
										sed -i -e "s/SSLCertificateKeyFile \/etc\/pki\/tls\/private\/localhost.key/SSLCertificateKeyFile \/etc\/ssl\/private\/apache.key/" /etc/httpd/conf.d/ssl.conf
									elif [ $i = 80 ]; then
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
									elif [ $i = 100 ]; then
										#Restart Ldap service
										systemctl restart slapd.service
										#Restart the hhtpd service
										systemctl restart httpd.service
						
									fi
									echo $i
									sleep 1
								done 
							#show a dialog box of the bar changing
							} | whiptail --gauge "Please wait while configuring SSL" 6 60 0
							
							{
								#dialog box with a loading bar
								for ((i = 0 ; i <= 100 ; i+=20)); do
									if [ $i = 20 ]; then
										#install the basic configuration of LDAP admin
										ldapmodify -Y EXTERNAL  -H ldapi:/// -f /tmp/LDAP.cfg/db.ldif
									elif [ $i = 40 ]; then
										#instal the LDAP certifications
										ldapmodify -Y EXTERNAL  -H ldapi:/// -f /tmp/LDAP.cfg/certs.ldif
									elif [ $i = 60 ]; then
										#install the configuration of the schemas in LDAP
										ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
										ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif 
										ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
									elif [ $i = 80 ]; then
										#install the configuration of access of the LDAP admin
										ldapmodify -Y EXTERNAL  -H ldapi:/// -f /tmp/LDAP.cfg/monitor.ldif

									elif [ $i = 100 ]; then
										#install  the base of LDAP server
										ldapadd -x -w $Passwd -D $RootD -f /tmp/LDAP.cfg/base.ldif
									fi
									#show the loading bar
									echo $i
									#take a second
									sleep 1
								done
							#dialog box
							} | whiptail --gauge "Please wait while the configuration finish" 6 60 0				
						fi
					fi
				fi
		elif [ $Menu = 3 ]; then
			#dialog box that allows the user to introduce the name of the new group
			Group=$(whiptail --title "LDAP group" --inputbox "please introduce the name of the group. for example:" 10 60 cn=namegroup,ou=Group,dc=example,dc=net  3>&1 1>&2 2>&3)
			option=$?
			#cut the variable Group to be introduced in the ldif file
			Ngroup=$(echo $Group | awk -F[=,] '{print $2}')
			if [ $option = 0 ]; then
				#create the ldif file with the new group
				sh -c 'cat > /tmp/LDAP.cfg/groups.ldif' << EF
dn: $Group
cn: $Ngroup
gidnumber: 500
objectclass: posixGroup
objectclass: top
EF
				#dialog box that prove that the user is allow to modify the LDAP server. allows to introduce the root user (administrator)
				RootD=$(whiptail --title "LDAP group" --inputbox "please introduce the LDAP account for root to verify administrator. for example:" 10 60 cn=admin,dc=example,dc=net 3>&1 1>&2 2>&3)
				option=$?
				if [ $option = 0 ]; then
					#dialog box that allows to introduce the root password to confirm the configuration
					Passwd=$(whiptail --title "LDAP group" --passwordbox "please introduce the LDAP root account password." 10 60 3>&1 1>&2 2>&3)
					option=$?
					if [ $option = 0 ]; then
						{	
							#install the new group in the LDAP server
							ldapadd -x -w $Passwd -D $RootD -f /tmp/LDAP.cfg/groups.ldif
							#dialog box that verify configuration
						} | whiptail --title "LDAP group" --msgbox "Group created" 10 60
					fi	
				fi
			fi
		elif [ $Menu = 4 ]; then
			User=$(whiptail --title "LDAP User" --inputbox "please introduce the name of the user. for example:" 10 60 cn=username,ou=People,dc=example,dc=net  3>&1 1>&2 2>&3)
			option=$?
			Nuser=$(echo $User | awk -F[=,] '{print $2}')
			useradd $Nuser
			if [ $option = 0 ]; then
				Passwd=$(whiptail --title "LDAP User" --passwordbox "please introduce the user password." 10 60 3>&1 1>&2 2>&3)
				passw=$(slappasswd -s $Passwd -h {SSHA})
				option=$?

				if [ $option = 0 ]; then
					sh -c 'cat > /tmp/LDAP.cfg/users.ldif' << EF
dn: $User
cn: $Nuser
gidnumber: 500
givenname: $Nuser
homedirectory: /home/$Nuser
objectclass: inetOrgPerson
objectclass: posixAccount
objectclass: top
sn: 1
uid: $Nuser
uidnumber: 1000
userpassword: $passw
EF

					RootD=$(whiptail --title "LDAP User" --inputbox "please introduce the LDAP account for root to verify administrator. for example:" 10 60 cn=admin,dc=example,dc=net 3>&1 1>&2 2>&3)
					option=$?
					if [ $option = 0 ]; then
						Passw=$(whiptail --title "LDAP User" --passwordbox "please introduce the LDAP root account password." 10 60 3>&1 1>&2 2>&3)
						option=$?
						if [ $option = 0 ]; then
							{	
								ldapadd -x -w $Passw -D $RootD -f /tmp/LDAP.cfg/users.ldif
							} | whiptail --title "LDAP User" --msgbox "User Created" 10 60
						fi
					fi
				fi
			fi
			
		elif [ $Menu = 5 ]; then
			DelGroup=$(whiptail --title "LDAP Delete User" --inputbox "please introduce the name of the group you want to delete. for example:" 10 60 cn=username,ou=People,dc=example,dc=net  3>&1 1>&2 2>&3)	
			option=$?
			if [ $option = 0 ]; then
				sh -c 'cat > /tmp/LDAP.cfg/delgroup.ldif' << EF
dn: $DelGroup
changetype: delete
EF
				RootD=$(whiptail --title "LDAP User" --inputbox "please introduce the LDAP account for root to verify administrator. for example:" 10 60 cn=admin,dc=example,dc=net 3>&1 1>&2 2>&3)
				option=$?
				if [ $option = 0 ]; then
					Passw=$(whiptail --title "LDAP User" --passwordbox "please introduce the LDAP root account password." 10 60 3>&1 1>&2 2>&3)
					option=$?

					if [ $option = 0 ]; then
						{	
							ldapadd -x -w $Passw -D $RootD -f /tmp/LDAP.cfg/users.ldif
						} | whiptail --title "LDAP User" --msgbox "User Deleted" 10 60
					fi
				fi
			fi
			
		elif [ $Menu = 6 ]; then
			DelUser=$(whiptail --title "LDAP Delete User" --inputbox "please introduce the name of the user you want to delete. for example:" 10 60 cn=username,ou=People,dc=example,dc=net  3>&1 1>&2 2>&3)	
			option=$?
			Duser=$(echo $DelUser | awk -F[=,] '{print $2}')
			userdel $Duser
			rm -rf /home/$Duser
			if [ $option = 0 ]; then
				sh -c 'cat > /tmp/LDAP.cfg/delusers.ldif' << EF
dn: $DelUser
changetype: delete
EF
				RootD=$(whiptail --title "LDAP User" --inputbox "please introduce the LDAP account for root to verify administrator. for example:" 10 60 cn=admin,dc=example,dc=net 3>&1 1>&2 2>&3)
				option=$?

				if [ $option = 0 ]; then
					Passw=$(whiptail --title "LDAP User" --passwordbox "please introduce the LDAP root account password." 10 60 3>&1 1>&2 2>&3)
					option=$?

					if [ $option = 0 ]; then
						{	
							ldapadd -x -w $Passw -D $RootD -f /tmp/LDAP.cfg/users.ldif
						} | whiptail --title "LDAP User" --msgbox "Group Deleted" 10 60
					fi
				fi
			fi
 
		elif [ $Menu = 7 ]; then
			{
				for ((i = 0 ; i <= 120 ; i+=20)); do
					if [ $i = 20 ]; then
						yum -y remove openldap-servers
					elif [ $i = 40 ]; then
						yum -y remove openldap-clients
					elif [ $i = 60 ]; then
						yum -y remove httpd
					elif [ $i = 80 ]; then
						yum -y remove epel-release
					elif [ $i = 100 ]; then
						yum -y remove phpldapadmin
					fi
					echo $i
					sleep 1
				done 
			} | whiptail --gauge "Please wait while Uninstall" 6 60 0

			#dialog box
			whiptail --title "LDAP Installer" --msgbox "Packages removed." 10 60
		fi

	else		
		whiptail --title "LDAP configuration" --msgbox "Program Finished" 10 60
		break
	fi
done
