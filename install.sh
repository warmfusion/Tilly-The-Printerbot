#!/bin/bash

apt-get update
apt-get install libssl-dev imagemagick
gem install ruby-slack-client faye-websocket

echo "Setting up symlink for printerBot.rb to /usr/local/bin"
ln -s $(pwd)/printerBot.rb /usr/local/bin/printerbot


echo 'Remember to set your SLACK_AUTH_TOKEN in /etc/default/tillyprinterbot'
echo '  echo "SLACK_AUTH_TOKEN=xxxx" > /etc/default/tillyprinterbot '
echo ''
echo 'See project README for more information'
