#!/usr/bin/env ruby

require 'slack-ruby-client'
#require 'celluloid-io'
require 'json'
require 'date'

require 'escpos'
require 'escpos/image'
require 'chunky_png'


if ENV['SLACK_AUTH_TOKEN'].nil? || ENV['SLACK_AUTH_TOKEN'] == 'NOT_SET_YET'
  puts "SLACK_AUTH_TOKEN environment variable missing - Please check readme for installation instructions "
  puts "   - https://github.com/warmfusion/Tilly-The-Printerbot/"
  exit 1
end

REALTIME_TOKEN = ENV['SLACK_AUTH_TOKEN']
WEB_TOKEN = ENV['SLACK_AUTH_TOKEN']
PRINTER_TTY="/dev/ttyAMA0"
MESSAGE_BREAK="---"


class PrinterBot

  class SlackEvent < Escpos::Report
    attr_accessor :name
    attr_accessor :channelName
    attr_accessor :time
    attr_accessor :msg
  end
  # For boring reasons, we need to use two different Slack clients to operate
  # 1. The RealTime client is for obtaining Reaction events without needing to run
  #    a full server with public endpoint
  # 2. The Web client is for obtaining the 'item' to which the reaction was attached

  attr_accessor :client
  attr_accessor :webClient


  def start!()
    puts 'Preparing real-time client event handling...'
    client.on :hello do
      puts "Successfully connected, welcome '#{client.self.name}' to the '#{client.team.name}' team at https://#{client.team.domain}.slack.com."
    end

    client.on :reaction_added do |data|
      process_reaction_event(data)
    end


    client.on :close do |_data|
      puts "Client is about to disconnect"
    end

    client.on :closed do |_data|
      puts "Client has disconnected successfully!"
    end

    # start the real-time client to get events
    puts 'Starting real-time client...'
    client.start!
  end

  def process_reaction_event(data)
    # I'm only interested in the :printer: reaction
    return unless data['reaction'] == 'printer'

    puts data.to_json
  # has_more=true, messages=[#<Slack::Messages::Message reactions=#<Hashie::Array [#<Slack::Messages::Message count=1 name="printer" users=#<Hashie::Array ["U02NNVATL"]>>]> text="This is a much longer test to see if this can actually work, and what happens when <@U02NNVATL> is mentioned as part of the message, perhaps even <@U4X4VNPAP> as well… how curious" ts="1491855771.754467" type="message" user="U02NNVATL">], ok=true

    puts "Finding associated item using channel.history query: channel #{data.item.channel}, latest: #{data.item.ts} inclusive: true, count: 1"
    history = webClient.channels_history( channel: data.item.channel, latest: data.item.ts, inclusive: 'true', count: 1 )

    puts history.to_json

    msg = history.messages.first
    puts msg.to_json

    msgUser     = webClient.users_info user: msg['user']
    channelInfo = webClient.channels_info( channel: data.item.channel )

#    # FIXME This feels inelegant as a method of finding the right reaction and count
#    unless msg['reactions'].select{|x| x.name == 'printer' && x.count == 1}.length == 1
#      puts "Already handled print for this message... ignoring"
#      return
#    end


    client.message channel: data['item'].channel, text: "Ok <@#{data.user}>... I'm trying to print that for you..."

    event = SlackEvent.new File.join(__dir__, 'slackMessage.erb')
    event.name = msgUser['user']['name']
    event.time = DateTime.strptime(data.item.ts,'%s')
    event.channelName = channelInfo['channel']['name_normalized']
    event.msg = msg


    @printer = Escpos::Printer.new
    @printer.write event.render


    if msg['attachments']
      image= get_image( get_image_path(msg['attachments'].first ) )
      @printer.write image.to_escpos
    end

    send_data_to_printer @printer.to_escpos
  end

  def get_image_path(attached)
    image_path=nil
    # Web links do this
    image_path = attached['image_url'] unless attached['image_url'].nil?
    # YouTube does this
    image_path = attached['thumb_url'] unless attached['thumb_url'].nil?

    image_path
  end

  def get_image(image_path)
    puts "Trying to print image from #{image_path}"
    return if image_path.nil?
    #image = Escpos::Image.new image_path
    # to use automatic conversion to monochrome format (requires mini_magick gem) use:
    image = Escpos::Image.new image_path, {
      convert_to_monochrome: true,
      dither: true, # the default
      extent: true, # the default
    }

    image
  end


  def send_data_to_printer(data)

    fd = IO.sysopen PRINTER_TTY, "w"
    ios = IO.new(fd, "w")
    ios.puts data
    # Printing Handled
    ios.close
  end

end

# Prepare the clients
Slack::RealTime.configure do |config|
  config.token = REALTIME_TOKEN
  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger::WARN
  fail 'Missing ENV[SLACK_AUTH_TOKEN]!' unless config.token
end

Slack::Web.configure do |config|
  config.token = WEB_TOKEN
  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger::WARN
  fail 'Missing ENV[SLACK_AUTH_TOKEN]!' unless config.token
end


printerBot = PrinterBot.new
printerBot.client = Slack::RealTime::Client.new
printerBot.webClient = Slack::Web::Client.new

printerBot.start!
