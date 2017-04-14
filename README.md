This is Tilly... a printer bot that'll print messages from slack onto till roll
thermal paper for posterity/evidence for your team.

![Tilly - The Slackbot Printer](Tilly-v1.0-Demo.jpg)


# Usage

1. Follow the Setup instructions below to get API tokens and the service running
1. Add `@tilly` (or whatever you named your integration) to the room
1. 'React' to a message with the `:printer:` emoji and the printer will do its thing

## Known Issues

- Adding `@tilly` to a private channel seems to change the internal id so older messages
    can't be found as the channel ID doesn't exist..?
- @mentions are showing internal ID values rather than friendly names

## TODO

- [x] Print message based on emoji event
- [ ] Write better documentation about the build
- [ ] Support command line configuration for printer endpoint/token
- [ ] Include real usernames when message includes @mentions
    - Currently includes <@U4X4xxxx> strings which isn't so nice
- [ ] Print avatar/emoji characters inline in message
- [ ] Show images for
    - [ ] Giphy embeds (Currently blank as no 'message' included)
    - [ ] Uploaded images/photos
    - [ ] Unfurled links - Youtube/websites etc
- [ ] Better installation solution using bundler or similar


# Building The Hardware

Heres a working prototype before she got her lovely case.

[![Tilly - The Slackbot Printer](Tilly-v0.1-YouTube.png)](https://www.youtube.com/watch?v=tEmO9eDk9JQ "Tilly - The Slackbot Printer")

## Parts List

1. Raspberry Pi
2. [Thermal Printer](https://www.sparkfun.com/products/10438)
    - Mine is TTY only, but USB _should_ work if you change `PRINTER_TTY`
3. Power cables 5v/2A for the printer as well as USB / ethernet etc
4. Googly Eyes - Optional

## Building

1. Pop the TTY connection onto pins 6,8,10 (GND,GPIO14, GPIO15)
2. Thats about it...

# The Software

## Prepare

1. Create a new Custom Bot integration
    - Can't use a 'App Bot' account as the `channels.history` API is not accessible
    and as tilly can be added to any room and interact with messages in the past this
    is a required permission.
1. Connect up printer+start app
1. git clone https://github.com/warmfusion/Tilly-The-Printerbot.git


## Install

   ./install.sh

If you are using jessie, or a systemd managed operating system, a systemd unit
file has been included for your convinence.

Simply follow the instructions below to ensure that your Tilly Printer Bot will
start automatically when your RPi is booted up for hands free operation.

    cp printerbot.service /etc/systemd/system/
    systemctl daemon-reload              # Tell systemd that theres a new service in town
    systemctl enable printerbot.service  # Ensure it starts on boot
    systemctl start printerbot           # Start it up for now

    # Check service output with
    journalctl -u printerbot


## Execute

1. `echo "SLACK_AUTH_TOKEN=YOURTOKEN" > /etc/default/tillyprinterbot`
1. `systemctl restart printerbot`  # Or SLACK_AUTH_TOKEN=xxxx ruby printerBot.rb
1. Add @printerbot (or whatever you named your integration) to rooms
1. 'React' to a message with the `:printer:` emoji and the printer will do its thing
