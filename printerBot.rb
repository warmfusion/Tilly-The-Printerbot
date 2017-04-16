#!/usr/bin/env ruby

require 'slack-ruby-client'
#require 'celluloid-io'
require 'json'
require 'date'

require 'escpos'
require 'escpos/image'
require 'chunky_png'

require 'logger'


if ENV['SLACK_AUTH_TOKEN'].nil? || ENV['SLACK_AUTH_TOKEN'] == 'NOT_SET_YET'
  puts "SLACK_AUTH_TOKEN environment variable missing - Please check readme for installation instructions "
  puts "   - https://github.com/warmfusion/Tilly-The-Printerbot/"
  exit 1
end

REALTIME_TOKEN = ENV['SLACK_AUTH_TOKEN']
WEB_TOKEN = ENV['SLACK_AUTH_TOKEN']
PRINTER_TTY="/dev/ttyAMA0"
MESSAGE_BREAK="---"

UPSIDE_DOWN=true
PRINTER_CHAR_WIDTH= 32

# Set to true to stop sending to printer - useful for debuggin
DEBUG_NO_PRINT=false

class PrinterBot


  class UnableToDetectChannelType < StandardError
  end

  class SlackEvent < Escpos::Report
    attr_accessor :name
    attr_accessor :channelName
    attr_accessor :time
    attr_accessor :msg

    def render()
      text = super
      # Word-Wrap time - Ensure fits to page
      # https://www.safaribooksonline.com/library/view/ruby-cookbook/0596523696/ch01s15.html
      text = text.gsub(/(.{1,#{PRINTER_CHAR_WIDTH}})(\s+|\Z)/, "\\1\n")
      if UPSIDE_DOWN
        text = text.split("\n").reverse().join("\n")
      end
      text
    end
  end
  # For boring reasons, we need to use two different Slack clients to operate
  # 1. The RealTime client is for obtaining Reaction events without needing to run
  #    a full server with public endpoint
  # 2. The Web client is for obtaining the 'item' to which the reaction was attached

  attr_accessor :client
  attr_accessor :webClient
  attr_accessor :log


  def start!()

    log.info 'Retrieving list of users..'
    user_resp = webClient.users_list
    @users = user_resp['members']
    log.debug "Loaded #{@users.length} user objects into memory"

    log.info 'Preparing real-time client event handling...'
    client.on :hello do
      log.info "Successfully connected, welcome '#{client.self.name}' to the '#{client.team.name}' team at https://#{client.team.domain}.slack.com."
    end

    client.on :reaction_added do |data|
      process_reaction_event(data)
    end


    client.on :close do |_data|
      log.info "Client is about to disconnect"
    end

    client.on :closed do |_data|
      log.info "Client has disconnected successfully!"
    end

    # start the real-time client to get events
    log.debug 'Starting real-time client...'
    client.start!
  end

  def process_reaction_event(data)
    # I'm only interested in the :printer: reaction
    return unless data['reaction'] == 'printer'
    log.debug "Reaction event occurred for :printer:..."
    log.debug data.to_json

    log.debug "Getting message information for item"
    msg         = get_message(data)
    msg['text'] = replace_mentions(msg['text'])
    log.debug msg.to_json

    log.debug "Getting user information for: #{msg['user']}"
    msgUser     = get_user msg['user']
    log.debug msgUser.to_json


    log.debug "Getting channel information for #{data.item.channel}"
    channelInfo = get_channel(data)
    log.debug channelInfo.to_json

#    # FIXME This feels inelegant as a method of finding the right reaction and count
#    unless msg['reactions'].select{|x| x.name == 'printer' && x.count == 1}.length == 1
#      puts "Already handled print for this message... ignoring"
#      return
#    end

    log.debug "Sending ack to user that we're going to try and print"
    client.message channel: data['item'].channel, text: "Ok <@#{data.user}>... I'm trying to print that for you..."

    log.debug "Building SlackEvent report object"
    event = SlackEvent.new File.join(__dir__, 'slackMessage.erb')
    event.name = msgUser['name']
    event.time = DateTime.strptime(data.item.ts,'%s')
    event.channelName = channelInfo['name_normalized'] unless channelInfo.nil?
    event.msg = msg

    log.info "Sending event to printer :: ##{event.channelName} - #{event.name} - #{event.time}"
    @printer = Escpos::Printer.new
    if UPSIDE_DOWN
      # https://cdn-shop.adafruit.com/datasheets/CSN-A2+User+Manual.pdf
      log.debug 'Setting printer to upsidedown mode...'
      @printer.write Escpos.sequence( [ 0x1B, 0x7B, 0x01 ] )
    end

    # FIXME: This assumes upside down is set as images come _after_ the text
    if msg['attachments']
      log.info "Item has attachment - trying to print image where exists"
      image= get_image( get_image_path(msg['attachments'].first ) )
      log.debug "Image returned: #{image}"
      @printer.write image.to_escpos unless image.nil?
    end

    log.debug event.render
    @printer.write event.render
    send_data_to_printer @printer.to_escpos

    # Feed feed feed
    send_data_to_printer "\n\n\n"
    log.info "Print Reaction Completed"
  end

  def get_message(data)
    #Public rooms, Private Rooms and Direct Messages each have their own API endpoints
    channel_first_letter = data.item.channel[0]

    history = nil
    case channel_first_letter
    when 'C' #Public Channel
      log.debug "Checking public channels history for item"
      history = webClient.channels_history( channel: data.item.channel, latest: data.item.ts, inclusive: 'true', count: 1 )
    when 'D'
      log.debug "Checking direct message history for item"
      history = webClient.im_history( channel: data.item.channel, latest: data.item.ts, inclusive: 'true', count: 1 )
    when 'G'
      log.debug "Checking group history for item"
      history = webClient.groups_history( channel: data.item.channel, latest: data.item.ts, inclusive: 'true', count: 1 )
    else
      log.warn "Couldn't detect Channel Type for #{data.item.channel} - Aborting"
      raise UnableToDetectChannelType "Did not recognise Channel Short Ident: #{data.item.channel}"
    end

    log.debug  history.to_json
    history.messages.first unless history.messages.nil?
  end


  def get_channel(data)
    channel_first_letter = data.item.channel[0]

    case channel_first_letter
    when 'C' #Public Channel
      log.debug "Checking public channels history for item"
      return webClient.channels_info( channel: data.item.channel )['channel']
    when 'D'
      log.debug "No Channel information exists for direct messages"
      return {}
    when 'G'
      log.debug "Checking group history for item"
      return webClient.groups_info( channel: data.item.channel )['group']
    else
      log.warn "Couldn't detect Channel Type for #{data.item.channel} - Aborting"
      raise UnableToDetectChannelType "Did not recognise Channel Short Ident: #{data.item.channel}"
    end
    return nil
  end

  def get_user(user_id)
    log.debug "Locating User object for #{user_id}"
    @users.find{ |u| u['id'] == user_id }
  end

  def replace_mentions(msg_text)
    msg_text.gsub(/\<([^\>]*)\>/){ |id|
       # Might fail if user can't be found.. (ie is new since app started)
        ux = get_user id[2..-2]
        '@' + ux['name']
      }
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
    log.info "Trying to print image from #{image_path}"
    return if image_path.nil?
    rotate = 0
    rotate = 180 if UPSIDE_DOWN
    #image = Escpos::Image.new image_path
    # to use automatic conversion to monochrome format (requires mini_magick gem) use:
    image = Escpos::Image.new image_path, {
      rotate: rotate,
      resize: '360x360',
      convert_to_monochrome: true,
      dither: true, # the default
      extent: true, # the default
    }
    image
  end


  def send_data_to_printer(data)
    # Bypass printing to save on paper
    return  if DEBUG_NO_PRINT

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

log = Logger.new(STDOUT)
log.level = Logger::DEBUG

printerBot = PrinterBot.new
printerBot.client = Slack::RealTime::Client.new
printerBot.webClient = Slack::Web::Client.new
printerBot.log = log

printerBot.start!
