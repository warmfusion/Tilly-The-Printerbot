require 'slack-ruby-client'
#require 'celluloid-io'
require 'json'
require 'date'
require 'rghost'

REALTIME_TOKEN = ENV['SLACK_AUTH_TOKEN']
WEB_TOKEN = ENV['SLACK_AUTH_TOKEN']
PRINTER_TTY="/dev/ttyAMA0"
MESSAGE_BREAK="---"



class PrinterBot

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

  def initialize()

      # https://cdn-shop.adafruit.com/datasheets/CSN-A2+User+Manual.pdf
      puts 'Setting printer to upsidedown mode...'
      send_message_to_printer "\x1B\x7B\x01"

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


    channelInfo = webClient.channels_info( channel: data.item.channel )
    channelName = channelInfo['channel']['name_normalized']

#    # FIXME This feels inelegant as a method of finding the right reaction and count
#    unless msg['reactions'].select{|x| x.name == 'printer' && x.count == 1}.length == 1
#      puts "Already handled print for this message... ignoring"
#      return
#    end

    msgUser =  webClient.users_info user: msg['user']
    puts "Message was from %s" % msgUser.to_json

    time = DateTime.strptime(data.item.ts,'%s')

    name = msgUser['user']['name']

    msgLines = []
    msgLines << MESSAGE_BREAK
    msgLines << "Who  : #{name}"
    msgLines << "When : #{time.strftime('%c')}"
    msgLines << "Where: ##{channelName}"
    msgLines << MESSAGE_BREAK
    msgLines.push *msg.text.split('\n') # newlines need to be split to let us reverse later
    msgLines << MESSAGE_BREAK

    client.message channel: data['item'].channel, text: "Ok <@#{data.user}>... I'm trying to print that for you..."

    msgPrinted = send_message_to_printer msgLines

    puts 'Made the following message permanant...'
    puts msgPrinted
  end

  def send_message_to_printer(msg, options = {})
    default_options = {
      :feed        => 3,
      :orientation => 'inverted',
      :width       => 32,
    }
    options = options.reverse_merge(default_options)

    # Word-Wrap time
    # https://www.safaribooksonline.com/library/view/ruby-cookbook/0596523696/ch01s15.html

    if msg.is_a? Array
      msg = msg.join("\n")
    end


    # Word-Wrap time
    # https://www.safaribooksonline.com/library/view/ruby-cookbook/0596523696/ch01s15.html
    msg = msg.gsub(/(.{1,#{options[:width]}})(\s+|\Z)/, "\\1\n")

    # Life got flipped, turned upside-down
    if options[:orientation] == 'inverted'
      msg = msg.split("\n").reverse.join("\n")
    end

    # Could use a long-lived socket here, but dont plan to print
    # _alot_ of things, so new connections are ok
    fd = IO.sysopen PRINTER_TTY, "w"
    ios = IO.new(fd, "w")
    ios.puts msg

    # Theres a feed action, but why bother
    options[:feed].times do ios.puts "\n" end

    # Printing Handled
    ios.close

    # return the msg
    msg
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
