require 'rest_client'

module OpenChain; class FreshserviceClient
  attr_accessor :token, :change_id, :request_complete

  def initialize fs_token=default_fs_token('config/freshservice_client.yml')
    @token = fs_token
    @request_complete = false
  end

  def change_url
    "https://vandegrift.freshservice.com/itil/changes.json"
  end

  def note_url
    "https://vandegrift.freshservice.com/itil/changes/#{change_id}/notes.json"
  end
  
  def create_change! instance, new_version, server_name
    if token.blank?
      raise "FreshserviceClient failed: No fs_token set. (Try setting up the freshservice_client.yml file)"
    end
    if request_complete
     raise "FreshserviceClient failed: This change request has already been sent!"
    end
    
    retry_count = 0
    begin
      response = RestClient::Request.execute({user: token, 
                                              password: "password", 
                                              method: "POST", 
                                              headers: {content_type: "text/json"}, 
                                              url: change_url, 
                                              payload: change_request(instance, new_version, server_name)})
    rescue => e
      retry if (retry_count += 1) < 4
      log e
    end
    @change_id = JSON.parse(response)["item"]["itil_change"]["display_id"]
  end

  def add_note! message
    if token.blank?
      raise "FreshserviceClient failed: No fs_token set. (Try setting up the freshservice_client.yml file)"
    elsif change_id.blank?
      raise "FreshserviceClient failed: No change_id set."
    end
    
    return if request_complete
    
    retry_count = 0
    begin
      RestClient::Request.execute({user: token, 
                                   password: "password", 
                                   method: "POST", 
                                   headers: {content_type: "text/json"}, 
                                   url: note_url, 
                                   payload: note_request(message)})
      @request_complete = true
    rescue => e
      retry if (retry_count += 1) < 4
      log e
    end
  end

  def add_note_with_log! upgrade_log
    add_note! stringify_log(upgrade_log)
  end

  # Serialized RestClient errors caused DelayedJob to choke. Log only the essentials.
  def log e
    begin
      raise e.class, e.message, e.backtrace
    rescue => err
      err.log_me
    end
  end

  private 

  def stringify_log upgrade_log
    "From version: #{upgrade_log.from_version}\nTo version: #{upgrade_log.to_version}\nStarted: #{upgrade_log.started_at}\nFinished: #{upgrade_log.finished_at}\n\n#{upgrade_log.log}"
  end

  def change_request instance, new_version, server_name
    planned_start_date = ActiveSupport::TimeZone["UTC"].now
    planned_end_date = planned_start_date + 3.minutes
    sub = "VFI Track Upgrade - #{instance} - #{new_version} - #{server_name}"
    {itil_change:
      {
        :subject => sub,
        :description => sub,
        :email => "support@vandegriftinc.com",
        :status => 1,
        :impact => 1,
        :change_type => 2,
        :group_id => 4000156520,
        :planned_start_date => planned_start_date.iso8601,
        :planned_end_date => planned_end_date.iso8601
      }
    }
  end

  def note_request message
    {
      "itil_note": {
          "body":"#{message}"
       }
    }
  end


  def default_fs_token fs_config
    @@token ||= ''
    if @@token.blank? && File.exist?(fs_config)
      @@token = YAML.load_file(fs_config).fetch('VFITRACK_FRESHSERVICE_TOKEN', '')
    end
    @@token
  end

end; end