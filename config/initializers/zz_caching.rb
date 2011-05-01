  #caching support
  CACHE = Dalli::Client.new ['localhost:11211'], {:namespace=>MasterSetup.get.uuid}
