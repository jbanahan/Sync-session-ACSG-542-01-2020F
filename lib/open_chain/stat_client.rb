require 'net/https'
#Client to send aggregated stats to the stat collector server
module OpenChain; class StatClient
  
  def self.collect_total_products
    add_numeric 'tot_prod', Product.scoped.count, Time.now
  end
  def self.add_numeric stat_code, value, collected_at
    h = {stat_code:stat_code,value:value,collected_at:collected_at}
    post_json! '/api/v1/stat_collector/add_numeric', h
  end

  def self.post_json! url, json_hash
    @@base_url ||= YAML.load(IO.read('config/stats_server.yml'))[Rails.env]['base_url']
    full_url = @@base_url + url
    uri = URI(full_url)
    req = Net::HTTP::Post.new(uri.path)
    req.set_content_type 'application/json'
    ms = MasterSetup.get
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
end; end
