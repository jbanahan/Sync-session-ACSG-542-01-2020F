require 'slack-ruby-client'

module OpenChain; class SlackClient
  attr_reader :slack_token
  def initialize token = ENV['VFITRACK_SLACK_TOKEN']
    @slack_token = token
    raise "SlackClient initialization failed: No slack_token set. (Try ENV['VFITRACK_SLACK_TOKEN'])" if Rails.env.production? && !@slack_token
    Slack.configure do |config|
      config.token = @slack_token
    end
    @client = Slack::Web::Client.new
  end

  #send a message and raise errors if needed
  def send_message! channel, text, slack_opts={}
    raise "Need slack channel." if channel.blank?
    raise "Need slack text." if text.blank?

    h = {as_user:true}.merge(slack_opts)

    #if overriding user info, then don't set as_user
    [:username,:icon_url,:icon_emoji].each {|x| h.delete(:as_user) unless h[x].blank?}

    #always set a username
    h[:username] = 'vfitrack-bot' if h[:as_user].blank? && h[:username].blank?


    h[:channel] = channel


    msg = "#{Rails.env.production? ? '' : 'DEV MESSAGE: '}#{text}"
    h[:text] = msg

    pp h
    @client.chat_postMessage(h) if @slack_token
  end

  #send message and swallow errors (fire & forget)
  def send_message channel, text, slack_opts={}
    begin
      self.send_message! channel, text, slack_opts
    rescue 
      #swallow errors on purpose
    end
  end
end; end;