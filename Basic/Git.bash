#!/bin/bash

sudo yum -y install git
git clone https://github.com/yolmant/Shells/
echo "Basic commands:
      git pull            # will get you repo updates
      git add .           # will add files in your dir
      git add [dirname]/* # will add files under a new dir
      git commit -m "your comment" # will commit your code to your changes
      git push            # will push your code to a reposatory
      git pull            # will pull down new reposatory updates
