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

  def send_message channel, text, slack_opts={}
    raise "Need slack channel." if channel.blank?
    raise "Need slack text." if text.blank?

    
    h = {as_user:true}.merge(slack_opts)
    h[:channel] = channel

    msg = "#{Rails.env.production? ? '' : 'DEV MESSAGE: '}#{text}"
    h[:text] = msg

    @client.chat_postMessage(h) if @slack_token
  end
end; end;