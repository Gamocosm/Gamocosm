#!/bin/sh

set -e

yum -y install java-1.7.0-openjdk-headless python3 python3-devel python3-pip supervisor proftpd

adduser mcuser
echo "minecraft" | passwd --stdin mcuser
su - mcuser -c "mkdir minecraft"

pip-python3 install flask

cd /opt/
mkdir gamocosm
cd gamocosm
wget -O minecraft-flask.py https://raw.github.com/Raekye/minecraft-server_wrapper/master/minecraft-flask.py

cat << 'EOF' > "/etc/supervisord.d/minecraft_wrapper.conf"
[program:minecraft_wrapper]
command=python3 /opt/gamocosm/minecraft-flask.py
autostart=true
autorestart=true
stderr_logfile=/opt/gamocosm/minecraft-flask-stderr.txt
stdout_logfile=/opt/gamocosm/minecraft-flask-stdout.txt
directory=/home/mcuser/minecraft/
stopasgroup=true
user=mcuser
EOF
