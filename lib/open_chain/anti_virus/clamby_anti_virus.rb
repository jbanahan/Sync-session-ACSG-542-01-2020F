require 'open_chain/anti_virus/anti_virus_helper'

# This anti-virus scanner utilizes the Clamby gem (which ultimately utilizes the Clam AV scanner on the local machine).
# Clamav must be installed and running in deamon mode.
#
# Instructions should be found on the clamby gem website: https://github.com/kobaltz/clamby
#
# They basically amount to running the following for Ubuntu servers: sudo apt-get install clamav clamav-daemon
#
# This will install clamav, set it up as a daemon (via systemd) and also set it up to update its AV database every 8 hours.
#
# You should also change the clamd.conf file to have the following changes:
#
# MaxScanSize 1500M
# MaxFileSize 1000M
# StreamMaxLength 1000M
#
#
module OpenChain; module AntiVirus; class ClambyAntiVirus
  extend OpenChain::AntiVirus::AntiVirusHelper

  def self.registered
    # Don't initialize anything if we're testing
    return nil if MasterSetup.test_env?

    require 'clamby'

    default_options = {
      check: true,
      daemonize: true,
      fdpass: true,
      # For some reason if stream is not utilized (even w/ fdpass set to true), file uploads are marked as viruses.
      stream: true,
      output_level: 'off'
    }

    # This allows for making changes to any clamby configuration values via the secrets file
    if MasterSetup.secrets['clamby'].is_a?(Hash)
      default_options = default_options.merge MasterSetup.secrets['clamby'].symbolize_keys
    end

    Clamby.configure(default_options)
    nil
  end

  def self.safe? file
    file = validate_file(file)
    # Use error logger just to see the log messages to track down why the system is saying all files uploaded via 
    # screen are viruses
    Clamby.safe? file
  end
  
end; end; end