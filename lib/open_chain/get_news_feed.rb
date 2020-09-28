require 'open_chain/http_client'

module OpenChain; class GetNewsFeed
  def self.run_schedulable
    self.delay.update_news
  end

  def self.update_news
    news = http_client.get('https://www.vandegriftinc.com/news?format=json')
    OpenChain::S3.upload_data 'vandegrift-news', 'latest_news.json', news
  end

  def self.http_client
    OpenChain::HttpClient.new
  end
  private_class_method :http_client
end; end
