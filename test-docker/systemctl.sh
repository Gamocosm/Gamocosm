#!/usr/bin/env bash
echo 'In Docker container; patching systemctl.'
if [[ "$1" == "start" ]] && [[ "$2" == "mcsw" ]]; then
	cd /home/mcuser/minecraft
	echo | python3 /opt/gamocosm/minecraft-server_wrapper.py daemonize mcsw.pid --auth=/opt/gamocosm/mcsw-auth.txt > /dev/null 2>&1
	sleep 2
	curl -d '{"ram": "512M"}' "http://gamocosm-mothership:$(sed -n 2p /opt/gamocosm/mcsw-auth.txt)@localhost:5000/start"
fi
