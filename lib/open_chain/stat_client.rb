require 'net/https'
#Client to send aggregated stats to the stat collector server
module OpenChain; class StatClient
  
  #main run class to collect all appropriate stats
  def self.run
    collect_active_users
    collect_total_products unless Product.scoped.empty? 
    collect_total_entries unless Entry.scoped.empty?
    collect_report_recipients unless SearchSchedule.scoped.empty?
    unless Survey.scoped.empty?
      collect_total_surveys
      collect_total_survey_responses
    end
  end

  def self.collect_active_users; total_count 'u_act_7', User.where('last_request_at > ?',7.days.ago); end
  def self.collect_total_survey_responses; total_count 'tot_survey_resp', SurveyResponse; end
  def self.collect_total_surveys; total_count 'tot_survey', Survey; end
  def self.collect_total_entries; total_count 'tot_ent', Entry; end
  def self.collect_total_products; total_count 'tot_prod', Product; end
  def self.collect_report_recipients 
    emails = Set.new
    SearchSchedule.scoped.pluck(:email_addresses).each do |addresses|
      next if addresses.blank?
      addresses.split(",").each do |interim_e| 
        interim_e.split(';').each {|e| emails << e.strip unless e.blank? or e =~ /vandegriftinc\.com/}
      end
    end
    total_count 'rep_recipients', emails
  end

  # Measures the total time of the statment in the passed in block and passes it to the stat code
  def self.wall_time stat_code
    s = Time.now.to_i
    yield
    add_numeric stat_code, Time.now.to_i - s
  end

  def self.add_numeric stat_code, value, collected_at=Time.now
    h = {stat_code:stat_code,value:value,collected_at:collected_at}
    post_json! '/api/v1/stat_collector/add_numeric', h
  end

  def self.post_json! url, json_hash
    ms = MasterSetup.get

    # If the stats API key is not set, then do nothing silently
    return nil if ms.stats_api_key.blank?

    raise "URL was blank" if url.blank?
    @@base_url ||= YAML.load(IO.read('config/stats_server.yml'))[Rails.env]['base_url']
    full_url = @@base_url + url
    uri = URI(full_url)
    req = Net::HTTP::Post.new(uri.path)
    req.set_content_type 'application/json'
    json_hash[:api_key] = ms.stats_api_key
    json_hash[:uuid] = ms.uuid
    req.set_form_data json_hash
    http = Net::HTTP.new(uri.host,uri.port)
    http.use_ssl = true if @@base_url =~ /^https/
    res =  http.request req
    case res.code
    when '200'
      return true
    when '400'
      raise "Request Error: #{JSON.parse(res.body)['error']}"
    else
      raise "Request Error: #{res.body}"
    end
  end

  private
  def self.total_count stat_code, obj
    add_numeric stat_code, (obj.respond_to?(:count) ? obj.count : obj.scoped.count), Time.now
  end
end; end
