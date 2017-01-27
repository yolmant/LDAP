#!/bin/bash

echo "installing apache server"
sudo yum -y install httpd

echo "enabling apache server"
sudo systemctl enable httpd.service

echo "starting apache server"
sudo systemctl start httpd.service

echo "If you open the security settings for port 80 on your server, you should see the apache start page"
