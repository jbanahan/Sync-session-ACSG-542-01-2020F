require 'slack-ruby-client'

module OpenChain; class SlackClient
  attr_reader :slack_token
  def initialize token = default_slack_token('config/slack_client.yml')
    @slack_token = token
    Slack.configure do |config|
      config.token = @slack_token
    end
    @client = self.class.slack_client
  end

  #send a message and raise errors if needed
  def send_message! channel, text, slack_opts={}
    raise "Need slack channel." if channel.blank?
    raise "Need slack text." if text.blank?
    raise "SlackClient initialization failed: No slack_token set. (Try setting up the slack_client.yml file)" if Rails.env.production? && @slack_token.blank?

    h = {as_user:true}.merge(slack_opts)

    #if overriding user info, then don't set as_user
    [:username,:icon_url,:icon_emoji].each {|x| h.delete(:as_user) unless h[x].blank?}

    #always set a username
    h[:username] = 'vfitrack-bot' if h[:as_user].blank? && h[:username].blank?

    h[:channel] = channel
    msg = "#{Rails.env.production? ? '' : 'DEV MESSAGE: '}#{text}"
    h[:text] = msg
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

  private 
    def default_slack_token slack_config
      @@token ||= ''
      if @@token.blank? && File.exist?(slack_config)
        @@token = YAML.load_file(slack_config)['VFITRACK_SLACK_TOKEN']
      end
      @@token
    end

    def self.slack_client
      Slack::Web::Client.new
    end
end; end;