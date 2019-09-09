require 'open_chain/anti_virus/anti_virus_helper'

module OpenChain; module AntiVirus; class TestingAntiVirus
  extend OpenChain::AntiVirus::AntiVirusHelper

  # Allows you to set the value returned whenever scan is invoked.
  cattr_accessor :scan_value

  def self.registered
    raise "The TestingAntiVirus implementation cannot be utilized in production." if MasterSetup.production_env?
    Rails.logger.info "Registering Fake Virus Scanner"
    @@scan_value = true
    nil
  end

  def self.safe? file
    file = get_file_path(file)
    Rails.logger.info "Fake Virus Scanning '#{file}'.  Returning: #{@@scan_value}"
    @@scan_value
  end

end; end; end