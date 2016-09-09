# Enables SNS Middleware for parsing SNS messages and auto-handling the topic subscription confirmation
if ActiveRecord::Base.connection.table_exists?('master_setups')
  topics = []

  if MasterSetup.first.try(:custom_feature?, "SNS Kewill Imaging")
    topics << "arn:aws:sns:us-east-1:468302385899:kewill-imaging"
  end

  if topics.length > 0
    require 'heroic/sns'
    Rails.application.config.middleware.use Heroic::SNS::Endpoint, topics: topics, auto_confirm: true, auto_resubscribe: false
  end
end
