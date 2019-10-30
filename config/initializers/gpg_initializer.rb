MasterSetup.config_value("gpg_path", default: "gpg1") do |gpg_path|
  require 'open_chain/gpg'

  OpenChain::GPG.gpg_binary = gpg_path
end