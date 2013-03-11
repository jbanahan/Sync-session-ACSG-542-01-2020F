module OpenChain
  module CustomHandler
    module AllianceProductSupport
      def ftp_credentials
        {:username=>'VFITRACK',:password=>'RL2VFftp',:server=>'ftp2.vandegriftinc.com',:folder=>'to_ecs/alliance_products',:remote_file_name=>remote_file_name}
      end
    end
  end
end
