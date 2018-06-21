# This check can be removed once we're on ruby 2.5 on circle
if RUBY_VERSION =~ /2\.2/
  require 'open_chain/gpg'
  OpenChain::GPG.gpg_binary = "gpg"
else
  MasterSetup.config_value("gpg_path", default: "gpg1") do |gpg_path|
    require 'open_chain/gpg'

    OpenChain::GPG.gpg_binary = gpg_path
  end
end