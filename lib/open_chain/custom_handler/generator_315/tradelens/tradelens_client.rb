require 'open_chain/json_http_client'

module OpenChain; module CustomHandler; module Generator315; module Tradelens; class TradelensClient
  attr_reader :http_client, :endpoint

  def initialize endpoint
    @endpoint = endpoint
    @http_client = OpenChain::JsonHttpClient.new
  end

  def send_milestone request_hsh, session_id, delay: false
    return unless MasterSetup.secrets["tradelens"]

    if delay
      self.class.delay.send_milestone(request_hsh, endpoint, session_id)
    else
      run request_hsh, session_id
    end
  end

  def url
    "https://#{domain}#{endpoint}"
  end

  def org_id
    MasterSetup.secrets["tradelens"]["org_id"]
  end

  def api_key
    MasterSetup.secrets["tradelens"]["api_key"]
  end

  def access_token use_cache: true
    ac_token = ::CACHE.get('tradelens_access_token') if use_cache
    if ac_token.blank?
      ac_token = generate_access_token
      ::CACHE.set('tradelens_access_token', ac_token)
    end
    ac_token
  end

  def onboarding_token use_cache: true
    ac_token = access_token(use_cache: use_cache)
    onb_token = ::CACHE.get('tradelens_onboarding_token') if use_cache
    if onb_token.blank?
      onb_token = generate_onboarding_token(ac_token)
      ::CACHE.set('tradelens_onboarding_token', onb_token)
    end
    onb_token
  end

  # This may eventually need to be moved into a support module for JSON APIs
  def log_response response_hsh, status, session_id
    session = ApiSession.find session_id
    session.retry_count += 1 if session.last_server_response.present?
    session.last_server_response = status
    Tempfile.open(["#{session.short_class_name}_response_#{session.retry_count + 1}_", ".json"]) do |t|
      t.binmode
      t << response_hsh.to_json
      t.flush
      att = Attachment.new(attachment_type: "response", attached: t,
                           attached_file_name: File.basename(t), uploaded_by: User.integration)
      session.attachments << att
    end
    session.save!
  end

  # For delayed jobs
  def self.send_milestone request_hsh, endpoint, session_id
    self.new(endpoint).run request_hsh, session_id
  end

  # consider this method "protected"

  def run request_hsh, session_id
    key = "#{request_hsh['equipmentNumber']}-#{request_hsh['billOfLadingNumber']}"

    Lock.acquire(key, yield_in_transaction: false) do
      use_cache = true
      retries_401 = 0
      response = nil
      status = nil
      begin
        onb_token = onboarding_token(use_cache: use_cache)
        response = http_client.post "https://#{domain}#{endpoint}",
                                    request_hsh.to_json,
                                    "Content-Type" => "application/json",
                                    "Accept" => "application/json",
                                    "Authorization" => "Bearer #{onb_token}"
        status = 'OK'
      rescue OpenChain::HttpErrorWithResponse => e
        # token has probably expired
        if e.http_status == "401" && (retries_401 += 1) < 10
          use_cache = false
          retry
        else
          response = e.http_response_body
          status = e.http_status
          raise e
        end
      ensure
        log_response(response, status, session_id)
      end
    end
  end

  private

  def generate_access_token
    http_client.post "https://iam.cloud.ibm.com/identity/token",
                     "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=#{api_key}",
                     "Content-Type" => "application/x-www-form-urlencoded"
  end

  def generate_onboarding_token access_token
     exchange_token = http_client.post("https://#{domain}/onboarding/v1/iam/exchange_token/solution/#{solution_id}/organization/#{org_id}",
                                       access_token,
                                       "Content-Type" => "application/json")
     exchange_token["onboarding_token"] if exchange_token
  end

  def domain
    MasterSetup.secrets["tradelens"]["domain"]
  end

  def solution_id
    MasterSetup.secrets["tradelens"]["solution_id"]
  end

end; end; end; end; end
