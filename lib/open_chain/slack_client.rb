require 'slack-ruby-client'

module OpenChain; class SlackClient

  #send a message and raise errors if needed
  def send_message! channel, text, slack_opts={}
    raise "Need slack channel." if channel.blank?
    raise "Need slack text." if text.blank?
    slack_enabled = self.class.slack_configured?
    if !slack_enabled
      raise "A Slack api_key has not been configured in secrets.yml" if MasterSetup.production_env?
      return nil
    end
    
    h = {as_user:true}.merge(slack_opts)

    #if overriding user info, then don't set as_user
    [:username,:icon_url,:icon_emoji].each {|x| h.delete(:as_user) unless h[x].blank?}

    #always set a username
    h[:username] = 'vfitrack-bot' if h[:as_user].blank? && h[:username].blank?

    h[:channel] = channel
    msg = "#{MasterSetup.production_env? ? '' : 'DEV MESSAGE: '}#{text}"
    h[:text] = msg
    slack_client.chat_postMessage(h)
    nil
  end

  #send message and swallow errors (fire & forget)
  def send_message channel, text, slack_opts={}
    begin
      self.send_message! channel, text, slack_opts
    rescue 
      #swallow errors on purpose
    end
  end

  def self.slack_configured?
    Slack.config.token.present?
  end

  private

    def slack_client
      Slack::Web::Client.new
    end
end; end;