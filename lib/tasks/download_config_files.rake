class DownloadConfigFiles
  include Rake::DSL

  def initialize
    namespace :environment do
      desc "Downloads config files from S3 bucket."

      task download_configs: :environment do
        require 'open_chain/load_environment'
        OpenChain::LoadEnvironment.download_config_files print_output: true
      end
    end
  end
end

DownloadConfigFiles.new