module OpenChain; class GetNewsFeed
  def self.run_schedulable
    self.delay.update_news
  end

  def self.update_news
    news = RestClient.get('https://www.vandegriftinc.com/news?format=json')
    OpenChain::S3.upload_data 'vandegrift-news', 'latest_news.json', news
  end
end; end
