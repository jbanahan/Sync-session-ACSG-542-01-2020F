require 'aws-sdk'
require 'open_chain/s3'
require 'open_chain/alliance_parser'
require 'open_chain/fenix_parser'
require 'open_chain/custom_handler/ack_file_handler'
require 'open_chain/custom_handler/ann_inc/ann_sap_product_handler'
require 'open_chain/custom_handler/ann_inc/ann_zym_ack_file_handler'
require 'open_chain/custom_handler/fenix_invoice_parser'
require 'open_chain/custom_handler/kewill_isf_xml_parser'
require 'open_chain/custom_handler/lenox/lenox_po_parser'
require 'open_chain/custom_handler/lenox/lenox_product_parser'
require 'open_chain/custom_handler/polo_msl_plus_enterprise_handler'
require 'open_chain/custom_handler/polo/polo_850_vandegrift_parser'
require 'open_chain/custom_handler/shoes_for_crews/shoes_for_crews_po_spreadsheet_handler'

module OpenChain
  class IntegrationClient
    def self.go system_code, shutdown_if_not_schedule_server = false, sleep_time = 5
      sqs = AWS::SQS.new(YAML::load_file 'config/s3.yml')
      q = sqs.queues.create system_code
      running = true
      while running
        begin
          in_memory_queue = []
          if ScheduleServer.active_schedule_server?
            IntegrationClient.messages(q) do |m|
              in_memory_queue << m
              m.visibility_timeout = 300 # 5 minutes
            end
          elsif shutdown_if_not_schedule_server
            running = false
          end
          in_memory_queue.sort! {|x,y| x.sent_timestamp <=> y.sent_timestamp}
          in_memory_queue.each do |m|
            begin
              cmd = JSON.parse m.body
              r = IntegrationClientCommandProcessor.process_command cmd
              raise r['message'] if r['response_type']=='error'
              running = false if r=='shutdown'
            rescue
              $!.log_me ["SQS Message: #{m.body}"]
            ensure
              m.delete
            end
          end
        rescue
          $!.log_me
        end
        sleep sleep_time
      end
    end

    # get the messages from the SQS queue
    def self.messages q
      while q.visible_messages > 0
        q.receive_message do |m|
          yield m
        end
      end
    end
  end
  class IntegrationClientCommandProcessor
    def self.process_command command
      case command['request_type']
      when 'remote_file'
        return process_remote_file command
      when 'shutdown'
        return 'shutdown'
      else
        return {'response_type'=>'error','message'=>"Unknown command: #{command}"}
      end
    end

    private
    def self.process_remote_file command
      bucket = OpenChain::S3.integration_bucket_name
      dir, fname = Pathname.new(command['path']).split
      remote_path = command['remote_path']
      status_msg = 'success'
      response_type = 'remote_file'
      if command['path'].include?('_alliance/') && MasterSetup.get.custom_feature?('alliance')
        OpenChain::AllianceParser.delay.process_from_s3 bucket, remote_path 
      elsif command['path'].include?('_fenix_invoices/') && MasterSetup.get.custom_feature?('fenix')
        OpenChain::CustomHandler::FenixInvoiceParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('_fenix/') && MasterSetup.get.custom_feature?('fenix')
        OpenChain::FenixParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('_kewill_isf/') && MasterSetup.get.custom_feature?('alliance')
        OpenChain::CustomHandler::KewillIsfXmlParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_from_msl/') && MasterSetup.get.custom_feature?('MSL+')
        if fname.to_s.match /-ack/
          OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: 'MSLE'
        else
          get_tempfile(bucket,remote_path,command['path']) do |tmp|
            h = OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.new
            h.send_and_delete_ack_file h.process(IO.read(tmp)), fname.to_s
          end
        end
      elsif command['path'].include?('_csm_sync/') && MasterSetup.get.custom_feature?('CSM Sync')
        get_tempfile(bucket,remote_path,command['path']) do |tmp|
          cf = CustomFile.new(:file_type=>'OpenChain::CustomHandler::PoloCsmSyncHandler',:uploaded_by=>User.find_by_username('rbjork'))
          cf.attached = tmp
          cf.save!
          cf.delay.process(cf.uploaded_by)
        end
      elsif command['path'].include?('_from_csm/ACK') && MasterSetup.get.custom_feature?('CSM Sync')
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: 'csm_product'
      elsif command['path'].include?('/_efocus_ack/') && MasterSetup.get.custom_feature?("e-Focus Products")
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: OpenChain::CustomHandler::PoloEfocusProductGenerator::SYNC_CODE
      elsif command['path'].include?('/_from_sap/') && MasterSetup.get.custom_feature?('Ann SAP')
        if fname.to_s.match /^zym_ack/
          OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: 'ANN-ZYM'
        else
          get_tempfile(bucket,remote_path,command['path']) do |tmp|
            OpenChain::CustomHandler::AnnInc::AnnSapProductHandler.new.process(IO.read(tmp),User.find_by_username('integration'))
          end
        end
      elsif command['path'].include? '/_polo_850/'
        OpenChain::CustomHandler::Polo::Polo850VandegriftParser.new.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include? '/_shoes_po/'
        OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoSpreadsheetHandler.new.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_lenox_product/') && MasterSetup.get.custom_feature?('Lenox')
        OpenChain::CustomHandler::Lenox::LenoxProductParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_lenox_po/') && MasterSetup.get.custom_feature?('Lenox')
        OpenChain::CustomHandler::Lenox::LenoxPoParser.delay.process_from_s3 bucket, remote_path
      elsif LinkableAttachmentImportRule.find_import_rule(dir.to_s)
        get_tempfile(bucket,remote_path,command['path']) do |temp|
          linkable = LinkableAttachmentImportRule.import(temp, fname.to_s, dir.to_s)
          if !linkable.errors.blank?
            response_type = 'error'
            status_msg = linkable.errors.full_messages.join("\n")
          end
        end
      elsif command['path'].include? '/to_chain/'
        get_tempfile(bucket,remote_path,command['path']) do |temp|
          status_msg = process_imported_file command, temp
          response_type = 'error' if status_msg != 'success'
        end
      else
        response_type = 'error'
        status_msg = "Can't figure out what to do for path #{command['path']}"
      end
      return {'response_type'=>response_type,(response_type=='error' ? 'message' : 'status')=>status_msg}
    end

    # expects path like /username/to_chain/module/search_name/file.ext
    def self.process_imported_file command, file
      dir, fname = Pathname.new(command['path']).split
      folder_list = dir.to_s.split('/')
      user = User.where(:username=>folder_list[1]).first
      raise "Username #{folder_list[1]} not found." unless user
      raise "User #{user.username} is locked." unless user.active?
      ss = user.search_setups.where(:module_type=>folder_list[3],:name=>folder_list[4]).first
      raise "Search named #{folder_list[4]} not found for module #{folder_list[3]}." unless ss
      imp = ss.imported_files.build(:starting_row=>1,:starting_column=>1,:update_mode=>'any')
      imp.attached = file
      imp.module_type = ss.module_type
      imp.user = user
      imp.save
      raise "Imported file could not be save: #{imp.errors.full_messages.join("\n")}" unless imp.errors.blank?
      imp.process user, {:defer=>true}
      return "success"
    end

    def self.get_tempfile bucket, remote_path, original_path
      OpenChain::S3.download_to_tempfile(bucket,remote_path) do |t|
        dir, fname = Pathname.new(original_path).split
        Attachment.add_original_filename_method t
        t.original_filename= fname.to_s
        yield t
      end
    end
  end
end
