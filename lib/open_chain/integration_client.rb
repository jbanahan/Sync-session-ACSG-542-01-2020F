require 'aws-sdk'
require 'open_chain/s3'
require 'open_chain/alliance_parser'
require 'open_chain/fenix_parser'
require 'open_chain/custom_handler/ack_file_handler'
require 'open_chain/custom_handler/ann_inc/ann_sap_product_handler'
require 'open_chain/custom_handler/ann_inc/ann_zym_ack_file_handler'
require 'open_chain/custom_handler/ecellerate_xml_router'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_po_parser'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_ftz_asn_generator'
require 'open_chain/custom_handler/fenix_invoice_parser'
require 'open_chain/custom_handler/j_jill/j_jill_850_xml_parser'
require 'open_chain/custom_handler/kewill_isf_xml_parser'
require 'open_chain/custom_handler/lenox/lenox_po_parser'
require 'open_chain/custom_handler/lenox/lenox_product_parser'
require 'open_chain/custom_handler/polo_msl_plus_enterprise_handler'
require 'open_chain/custom_handler/polo/polo_850_vandegrift_parser'
require 'open_chain/custom_handler/polo/polo_tradecard_810_parser'
require 'open_chain/custom_handler/shoes_for_crews/shoes_for_crews_po_spreadsheet_handler'
require 'open_chain/custom_handler/lands_end/le_parts_parser'
require 'open_chain/custom_handler/intacct/alliance_day_end_ar_ap_parser'
require 'open_chain/custom_handler/intacct/alliance_check_register_parser'

module OpenChain
  class IntegrationClient

    def self.run_schedulable opts = {}
      opts = {'queue_name' => MasterSetup.get.system_code, 'max_message_count' => 500}.merge opts
      process_queue opts['queue_name'], opts['max_message_count']
    end

    def self.process_queue queue_name, max_message_count = 500
      raise "Queue Name must be provided." if queue_name.blank?

      messages_processed = 0

      current_queue_messages = retrieve_queue_messages queue_name, max_message_count
      current_queue_messages.each do |m|
        begin
          cmd = JSON.parse m.body
          r = IntegrationClientCommandProcessor.process_command cmd
          raise r['message'] if r['response_type']=='error'
          messages_processed += 1

          # There's not really much point to a shutdown response with this running via a scheduler,
          # but I suppose it can't hurt either.
          break if r=='shutdown'
        rescue => e
          e.log_me ["SQS Message: #{m.body}"]
        ensure
          m.delete
        end
      end
      
      messages_processed
    end

    def self.retrieve_queue_messages queue_name, max_message_count
      sqs = AWS::SQS.new(YAML::load_file 'config/s3.yml')
      queue = sqs.queues.create queue_name
      available_messages = []
      # The max message count is just to try and avoid a situation where the 
      # message count gets out of control (due to something queueing files like crazy).
      
      # Considering the integration client should be set up to run every minute, limiting the
      # number of messages received per run shouldn't be an issue.
      while available_messages.length < max_message_count && queue.visible_messages > 0
        # NOTE: The messages are not deleted from the queue until delete is called on them
        # when receive_message is used in this manner (this is different than the block form of the method)
        messages = queue.receive_messages(visibility_timeout: (max_message_count + 60), limit: 10, attributes: [:sent_at], wait_time_seconds: 0)
        available_messages.push(*messages) if messages.size > 0
      end
      # AWS Queue messages are not guaranteed to be returned in order..this
      # is about the best we can do without actually numbering the message data and blocking
      # until missing numbers are received.
      available_messages.sort {|x,y| x.sent_at <=> y.sent_at}
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
    def self.process_remote_file command, total_attempts = 3
      # Even though this process runs in a delayed job queue, we still primarily want to delay()
      # the processing of each job so that each call to the process_remote_file runs quickly.  This
      # is because the processor really needs to make it through processing every message before
      # the message's visibility timeout "expires" and the sqs message goes back on the queue.

      # We're currently setting the visibility timeout per message in such a way that we get at least
      # 1 second per file to process (including any retries that may occur) without exceeding the visibility
      # timeout.

      bucket = OpenChain::S3.integration_bucket_name
      dir, fname = Pathname.new(command['path']).split
      remote_path = command['remote_path']
      status_msg = 'success'
      response_type = 'remote_file'
      if command['path'].include?('_alliance/') && MasterSetup.get.custom_feature?('alliance')
        OpenChain::AllianceParser.delay.process_from_s3 bucket, remote_path 
      elsif command['path'].include?('_alliance_day_end_invoices/') && MasterSetup.get.custom_feature?('alliance')
        OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser.delay.process_from_s3 bucket, remote_path, original_filename: fname.to_s
       elsif command['path'].include?('_alliance_day_end_checks/') && MasterSetup.get.custom_feature?('alliance')
        OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.delay.process_from_s3 bucket, remote_path, original_filename: fname.to_s
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
          OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.delay.send_and_delete_ack_file_from_s3 bucket, remote_path, fname.to_s
        end
      elsif command['path'].include?('_csm_sync/') && MasterSetup.get.custom_feature?('CSM Sync')
        OpenChain::CustomHandler::PoloCsmSyncHandler.delay.process_from_s3 bucket, remote_path, original_filename: fname.to_s
      elsif command['path'].include?('_from_csm/ACK') && MasterSetup.get.custom_feature?('CSM Sync')
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: 'csm_product', username: ['rbjork','aditaran']
      elsif command['path'].include?('/_efocus_ack/') && MasterSetup.get.custom_feature?("e-Focus Products")
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: OpenChain::CustomHandler::PoloEfocusProductGenerator::SYNC_CODE
      elsif command['path'].include?('/_from_sap/') && MasterSetup.get.custom_feature?('Ann SAP')
        if fname.to_s.match /^zym_ack/
          OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: 'ANN-ZYM'
        else
          OpenChain::CustomHandler::AnnInc::AnnSapProductHandler.delay.process_from_s3 bucket, remote_path
        end
      elsif command['path'].include? '/_polo_850/'
        OpenChain::CustomHandler::Polo::Polo850VandegriftParser.new.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include? '/_shoes_po/'
        OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoSpreadsheetHandler.new.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include? '/_eddie_po/'
        OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include? '/_eb_ftz_ack/'
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, {username:'eddie_ftz_notification',sync_code: OpenChain::CustomHandler::EddieBauer::EddieBauerFtzAsnGenerator::SYNC_CODE,csv_opts:{col_sep:'|'},module_type:'Entry'}
      elsif command['path'].include?('/_lenox_product/') && MasterSetup.get.custom_feature?('Lenox')
        OpenChain::CustomHandler::Lenox::LenoxProductParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_lenox_po/') && MasterSetup.get.custom_feature?('Lenox')
        OpenChain::CustomHandler::Lenox::LenoxPoParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include? '/_polo_tradecard_810'
        OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_jjill_850/') && MasterSetup.get.custom_feature?('JJill')
        OpenChain::CustomHandler::JJill::JJill850XmlParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_ecellerate_shipment')
        OpenChain::CustomHandler::EcellerateXmlRouter.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_lands_end_parts/') && MasterSetup.get.custom_feature?('Lands End Parts')
        OpenChain::CustomHandler::LandsEnd::LePartsParser.delay.process_from_s3 bucket, remote_path
      elsif LinkableAttachmentImportRule.find_import_rule(dir.to_s)
        LinkableAttachmentImportRule.delay.process_from_s3 bucket, remote_path, original_filename: fname.to_s, original_path: dir.to_s
      elsif command['path'].include? '/to_chain/'
        ImportedFile.delay.process_integration_imported_file bucket, remote_path, command['path']
      elsif command['path'].include?('/_test_from_msl') && MasterSetup.get.custom_feature?('MSL+')
        #prevent errors; don't do anything else
      else
        response_type = 'error'
        status_msg = "Can't figure out what to do for path #{command['path']}"
      end
      return {'response_type'=>response_type,(response_type=='error' ? 'message' : 'status')=>status_msg}
    rescue => e
      raise e unless Rails.env.production?
      
      total_attempts -= 1
      if total_attempts > 0
        sleep 0.25
        retry
      else
        raise e
      end
    end

  end
end
