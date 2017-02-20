#!/bin/bash
{
	apt-get --yes update && apt-get --yes upgrade && apt-get --yes dist-upgrade

} | whiptail --title "LDAP client" --msgbox "Updating the system to the lastest version. wait a minute" 10 60

export DEBIAN_FRONTEND=noninteractive

{
	apt-get --yes install libpam-ldap ncsd
	unset DEBIAN_FRONTEND

} | whiptail --title "LDAP client" --msgbox "Installing Ldap and authentication client package" 10 60

Domain=$(whiptail --title "LDAP client" --inputbox "introduce the LDAP domain. for example:" 10 60 dc=example,dc=net 3>&1 1>&2 2>&3)

Ips=$(whiptail --title "LDAP client" --inputbox "introduce the server IP:" 10 60 3>&1 1>&2 2>&3)
 	
