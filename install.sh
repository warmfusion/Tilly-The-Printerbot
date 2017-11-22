#!/bin/bash

#apt-get update
#apt-get install -y libssl-dev imagemagick
#gem install ruby-slack-client faye-websocket

echo "Setting up symlink for printerBot.rb to /usr/local/bin"
rm -f /usr/local/bin/printerbot
ln -s $(pwd)/printerBot.rb /usr/local/bin/printerbot

rm -f /etc/systemd/system/printerbot.service
ln -s $(pwd)/printerbot.service /etc/systemd/system/printerbot.service
systemctl daemon-reload

echo 'Remember to set your SLACK_AUTH_TOKEN in /etc/default/tillyprinterbot'
echo '  echo "SLACK_AUTH_TOKEN=xxxx" > /etc/default/tillyprinterbot '
echo ''
echo 'See project README for more information'
