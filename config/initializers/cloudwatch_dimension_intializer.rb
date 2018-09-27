require 'open_chain/cloud_watch'

if Rails.env.production?
  OpenChain::CloudWatch.add_default_dimension "Environment", (MasterSetup.get.production? ? "Production" : "Test")
  OpenChain::CloudWatch.add_default_dimension "System", MasterSetup.get.system_code
end