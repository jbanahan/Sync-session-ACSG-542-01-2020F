class RequestLog < ActiveRecord::Base
  belongs_to :user
  belongs_to :run_as_session, inverse_of: :request_logs
  has_one :attachment, as: :attachable, dependent: :destroy

  def self.build_log_from_request user, request, parameters
    log = RequestLog.new
    log.user = user
    log.http_method = request.method
    log.url = request.original_url

    request_id = request.uuid
    if request_id.blank?
      request_id = Time.zone.now.utc.strftime("%Y%m%d%H%M%S%L")
    end
    
    hash = request_to_hash(request, parameters)
    log.build_attachment attached: create_json_attachment(hash, "#{request_id}.json")

    log
  end

  def self.request_to_hash request, parameters
    data = {timestamp: Time.zone.now.utc.iso8601, method: request.method, url: request.original_url}
    data[:headers] = {}.tap do |headers|
      request.headers.each do |key, value|
        # So this is kinda weird...rails (rack?) makes all the real HTTP headers capitalized, doing this allows us
        # skip any crap that rails adds to the request that didn't originate from the actual browser request.
        headers[key] = value if key[0] == key[0].to_s.upcase
      end
    end

    data[:parameters] = {}.tap do |params|
      parameters.each do |key, value|
        # Any parameter that's not a string value is likely something like a file upload or something else that we don't actually want to log (like something rails injects into the params)
        # Any form field or something else is going to be a string coming from the browser.
        value = "[not captured]" unless value.is_a?(String)
        params[key] = value
      end
    end

    data
  end

  def self.create_json_attachment data, filename
    io = StringIOAttachment.new
    io.content_type = "application/json"
    io.original_filename = filename

    io.write data.to_json
    io.flush
    io.rewind

    io
  end
end