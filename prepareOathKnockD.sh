#!/bin/bash
THIS_DIR=`dirname $0`
#shopt -s expand_aliases
sudo yum install google-authenticator oathtool -y

USER_HOME=$(eval echo "~$USER")
FILES_PATH=${USER_HOME}
KEY_FILES_PATH="${USER_HOME}/google-authenticator-iptables-knock-"

echo "
[Unit]
Description=oathKnock node
After=network.target

[Service]
Type=forking
ExecStart=${THIS_DIR}/oathKnockD.sh --knockFiles=${KEY_FILES_PATH}

Restart=on-failure

[Install]
WantedBy=default.target
" | sudo tee /etc/systemd/system/oathKnock.service

sudo systemctl daemon-reload && \
sudo systemctl start oathKnock && \
sudo systemctl status oathKnock & disown
#
