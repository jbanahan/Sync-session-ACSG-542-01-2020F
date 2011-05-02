  #caching support
  
  require 'open_chain/test_extensions'

  cache_class = Rails.env=="test" ? TestExtensions::MockCache : Dalli::Client

  CACHE = cache_class.new ['localhost:11211'], {:namespace=>CacheManager.namespace}
