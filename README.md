This is a printerbot that'll print messages from slack.

# Usage

## TODO

- [x] Print message based on emoji event
- [ ] Write better documentation
- [ ] Support command line configuration for printer endpoint/token
- [ ] Include real usernames when message includes @mentions
    - Currently includes <@U4X4xxxx> strings which isn't so nice
- [ ] Print avatar/emoji characters inline in message
- [ ] Show images for
    - [ ] Giphy embeds (Currently blank as no 'message' included)
    - [ ] Uploaded images/photos
    - [ ] Unfurled links - Youtube/websites etc

# Setup Your PrinterBot

1. Get 'Custom Integration' token
  - Bot/OAuth keys don't work as they dont have permission to get arbitrary item data
    via web client
2. Connect up printer+start app
3. Add @printerbot (or whatever you named your integration) to rooms
4. 'React' to a message with the `:printer:` emoji and the printer will do its thing



## Installation

    apt-get install libssl-dev
    gem install ruby-slack-client faye-websocket

## Running

    SLACK_AUTH_TOKEN=${YOUR_TOKEN} ruby printerBot.rb
