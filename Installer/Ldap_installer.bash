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
		{	
			systemctl enable slapd.service
        		systemctl start slapd.service
        		systemctl enable httpd.service
        		systemctl start httpd.service
		
		} | whiptail --title "LDAP Installer" --msgbox "enabling and starting services" 10 60
		
		{
        		#sed -i 's,Require local,#Require local\n    Require all granted,g' /etc/httpd/conf.d/phpldapadmin.conf

        		systemctl restart httpd.service

        		setsebool -P httpd_can_connect_ldap on
      
		} | whiptail --title "LDAP Installer" --msgbox "services started and enabled" 10 60

	elif [ $Menu = 2 ]; then
		mkdir /tmp/LDAP.cfg
		i="0"
		while [ $i = 0 ] 
		do
			whiptail --title "LDAP configuration" --msgbox "this configuration will automatically setup in the LDAP server and any ldif file will be stored in the next directory ~/tmp/LDAP.cfg" 10 60

			Domain=$(whiptail --title "LDAP configuration" --inputbox "please introduce the domain or distinguished name. for example:" 10 60 dc=example,dc=net 3>&1 1>&2 2>&3)
			option=$?
			Do=$(echo $Domain | awk -F[=,] '{print $2}')
			if [ $option = 0 ]; then
				RootD=$(whiptail --title "LDAP configuration" --inputbox "please introduce the LDAP account for root. for example:" 10 60 cn=admin,dc=example,dc=net 3>&1 1>&2 2>&3)
				option=$?
				RD=$(echo $RootD | awk -F[=,] '{print $2}')
				if [ $option = 0 ]; then
					Passwd=$(whiptail --title "LDAP configuration" --passwordbox "please introduce the LDAP root account password. for example:" 10 60 3>&1 1>&2 2>&3)
					Passw=$(slappasswd -s $Passwd -h {SSHA})
					option=$?
					if [ $option = 0 ]; then
						{
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
						
							sh -c 'cat > /tmp/LDAP.cfg/monitor.ldif' << EF
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external, cn=auth" read by dn.base="$RootD" read by * none
EF	
	
							#creating a certification file
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

						} | whiptail --title "LDAP configuration" --msgbox "creating file. wait a minute" 10 60

						Co=$(whiptail --title "LDAP configuration" --inputbox "this prompt will create the LDAP certification for your server.\

please introduce the two initial of the country. for example:" 10 60 US 3>&1 1>&2 2>&3)

						St=$(whiptail --title "LDAP configuration" --inputbox "please introduce the two initial of the State. for example:" 10 60 WA 3>&1 1>&2 2>&3)

						ci=$(whiptail --title "LDAP configuration" --inputbox "please introduce the city. for example:" 10 60 Seattle 3>&1 1>&2 2>&3)

						Org=$(whiptail --title "LDAP configuration" --inputbox "please introduce the name of the Organization. for example:" 10 60 ITcorp 3>&1 1>&2 2>&3)

						O=$(whiptail --title "LDAP configuration" --inputbox "please introduce the Organizational Unit. for example:" 10 60 ITinfra 3>&1 1>&2 2>&3)

						Ca=$(whiptail --title "LDAP configuration" --inputbox "please introduce the Common Name. for example:" 10 60 server.NTI.local 3>&1 1>&2 2>&3)
			
						{
							openssl req -new -x509 -nodes -out /etc/openldap/certs/LDAPcert.pem -keyout /etc/openldap/certs/LDAPkey.pem -days 365 -subj "/C=$Co/ST=$St/L=$ci/O=$Org/OU=$O/CN=$Ca"
							chown -R ldap:ldap /etc/openldap/certs/*.pem			
						} | whiptail --title "LDAP configuration" --msgbox "certifications created" 10 60
						{

							cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
							chown ldap:ldap /var/lib/ldap/*

				                        for ((i = 0 ; i <= 100 ; i+=20)); do
                                				if [ $i = 20 ]; then
                               				        	ldapmodify -Y EXTERNAL  -H ldapi:/// -f /tmp/LDAP.cfg/db.ldif
								elif [ $i = 40 ]; then
                                			        	ldapmodify -Y EXTERNAL  -H ldapi:/// -f /tmp/LDAP.cfg/certs.ldif
                               					elif [ $i = 60 ]; then
                                        				ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
									ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif 
									ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
                                				elif [ $i = 80 ]; then
                                					ldapmodify -Y EXTERNAL  -H ldapi:/// -f /tmp/LDAP.cfg/monitor.ldif

                               					elif [ $i = 100 ]; then
                                					ldapadd -x -w $Passwd -D $RootD -f /tmp/LDAP.cfg/base.ldif
								fi
                                				echo $i
                                				sleep 1
                        					done
                				} | whiptail --gauge "Please wait while the configuration finish" 6 60 0
										
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

