require 'open_chain/sqs'
require 'open_chain/s3'
require 'open_chain/fenix_parser'
require 'open_chain/custom_handler/ack_file_handler'
require 'open_chain/custom_handler/ann_inc/ann_sap_product_handler'
require 'open_chain/custom_handler/ann_inc/ann_zym_ack_file_handler'
require 'open_chain/custom_handler/ascena/apll_856_parser'
require 'open_chain/custom_handler/baillie/baillie_order_xml_parser'
require 'open_chain/custom_handler/ecellerate_xml_router'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_po_parser'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_ftz_asn_generator'
require 'open_chain/custom_handler/eddie_bauer/eddie_bauer_commercial_invoice_parser'
require 'open_chain/custom_handler/fenix_invoice_parser'
require 'open_chain/custom_handler/hm/hm_i1_interface'
require 'open_chain/custom_handler/hm/hm_i2_shipment_parser'
require 'open_chain/custom_handler/j_jill/j_jill_850_xml_parser'
require 'open_chain/custom_handler/kewill_isf_xml_parser'
require 'open_chain/custom_handler/lenox/lenox_po_parser'
require 'open_chain/custom_handler/lenox/lenox_product_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_gtn_asn_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_sap_article_xml_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_sap_order_xml_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_sap_pir_xml_parser'
require 'open_chain/custom_handler/lumber_liquidators/lumber_sap_vendor_xml_parser'
require 'open_chain/custom_handler/polo_msl_plus_enterprise_handler'
require 'open_chain/custom_handler/polo/polo_850_vandegrift_parser'
require 'open_chain/custom_handler/polo/polo_tradecard_810_parser'
require 'open_chain/custom_handler/shoes_for_crews/shoes_for_crews_po_spreadsheet_handler'
require 'open_chain/custom_handler/lands_end/le_parts_parser'
require 'open_chain/custom_handler/lands_end/le_canada_plus_processor'
require 'open_chain/custom_handler/intacct/alliance_day_end_ar_ap_parser'
require 'open_chain/custom_handler/intacct/alliance_check_register_parser'
require 'open_chain/custom_handler/kewill_export_shipment_parser'
require 'open_chain/custom_handler/siemens/siemens_decryption_passthrough_handler'
require 'open_chain/custom_handler/polo/polo_850_parser'
require 'open_chain/custom_handler/ascena/ascena_po_parser'
require 'open_chain/custom_handler/burlington/burlington_850_parser'
require 'open_chain/custom_handler/burlington/burlington_856_parser'
require 'open_chain/custom_handler/amersports/amersports_856_ci_load_parser'

module OpenChain
  class IntegrationClient

    def self.run_schedulable opts = {}
      opts = {'queue_name' => MasterSetup.get.system_code, 'max_message_count' => 500}.merge opts
      process_queue opts['queue_name'], opts['max_message_count']
    end

    def self.process_queue queue_name, max_message_count = 500
      raise "Queue Name must be provided." if queue_name.blank?
      queue_url = OpenChain::SQS.create_queue queue_name

      messages_processed = 0
      current_queue_messages = retrieve_queue_messages queue_url, max_message_count
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
          OpenChain::SQS.delete_message queue_url, m
        end
      end

      messages_processed
    end

    def self.retrieve_queue_messages queue_url, max_message_count
      available_messages = []
      # The max message count is just to try and avoid a situation where the
      # message count gets out of control (due to something queueing files like crazy).

      # Considering the integration client should be set up to run every minute, limiting the
      # number of messages received per run shouldn't be an issue.
      while available_messages.length < max_message_count && OpenChain::SQS.visible_message_count(queue_url) > 0
        # NOTE: The messages are not deleted from the queue until delete is called on them
        # when receive_message is used in this manner (this is different than the block form of the method)
        response = OpenChain::SQS.retrieve_messages queue_url, max_number_of_messages: 10, wait_time_seconds: 0, visibility_timeout: (max_message_count + 60), attribute_names: [:SentTimestamp]
        available_messages.push(*response.messages) if response.messages.size > 0
      end
      # AWS Queue messages are not guaranteed to be returned in order..this
      # is about the best we can do without actually numbering the message data and blocking
      # until missing numbers are received.
      available_messages.sort_by {|msg| msg.attributes['SentTimestamp'].to_i }
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
      master_setup = MasterSetup.get
      if command['path'].include?('_alliance/') && master_setup.custom_feature?('alliance')
        # Just no-op if we get alliance files...the kewill_entry_parser feed handles these now.
      elsif command['path'].include?('_alliance_day_end_invoices/') && master_setup.custom_feature?('alliance')
        OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser.delay.process_from_s3 bucket, remote_path, original_filename: fname.to_s
      elsif command['path'].include?('_alliance_day_end_checks/') && master_setup.custom_feature?('alliance')
        OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.delay.process_from_s3 bucket, remote_path, original_filename: fname.to_s
      elsif command['path'].include?('_ascena_po/') && MasterSetup.get.custom_feature?('Ascena PO')
        OpenChain::CustomHandler::Ascena::AscenaPoParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('_ascena_apll_asn') && master_setup.custom_feature?('Ascena APLL ASN')
        OpenChain::CustomHandler::Ascena::Apll856Parser.delay.process_from_s3(bucket, remote_path)
      elsif command['path'].include?('/_po_xml') && master_setup.custom_feature?("Baillie")
        OpenChain::CustomHandler::Baillie::BaillieOrderXmlParser.delay.process_from_s3(bucket, remote_path)
      elsif command['path'].include?('_fenix_invoices/') && master_setup.custom_feature?('fenix')
        OpenChain::CustomHandler::FenixInvoiceParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('_fenix/') && (master_setup.custom_feature?('fenix') || master_setup.custom_feature?("Fenix B3 Files"))
        OpenChain::FenixParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('_hm_i1/') && master_setup.custom_feature?('H&M I1 Interface')
        OpenChain::CustomHandler::Hm::HmI1Interface.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?("/_hm_i2") && master_setup.custom_feature?('H&M I2 Interface')
        OpenChain::CustomHandler::Hm::HmI2ShipmentParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('_kewill_isf/') && master_setup.custom_feature?('alliance')
        OpenChain::CustomHandler::KewillIsfXmlParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_gtn_asn_xml') && master_setup.custom_feature?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberGtnAsnParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_sap_vendor_xml') && master_setup.custom_feature?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberSapVendorXmlParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_sap_po_xml') && master_setup.custom_feature?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_sap_article_xml') && master_setup.custom_feature?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberSapArticleXmlParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_sap_pir_xml') && master_setup.custom_feature?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberSapPirXmlParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_from_msl/') && master_setup.custom_feature?('MSL+')
        if fname.to_s.match /-ack/
          OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: 'MSLE', username: ['dlombardi','mgrapp','gtung']
        else
          OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.delay.send_and_delete_ack_file_from_s3 bucket, remote_path, fname.to_s
        end
      elsif command['path'].include?('_csm_sync/') && master_setup.custom_feature?('CSM Sync')
        OpenChain::CustomHandler::PoloCsmSyncHandler.delay.process_from_s3 bucket, remote_path, original_filename: fname.to_s
      elsif command['path'].include?('_from_csm/ACK') && master_setup.custom_feature?('CSM Sync')
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: 'csm_product', username: ['rbjork','aditaran']
      elsif command['path'].include?('/_efocus_ack/') && master_setup.custom_feature?("e-Focus Products")
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: OpenChain::CustomHandler::PoloEfocusProductGenerator::SYNC_CODE, username: ['rbjork']
      elsif command['path'].include?('/_from_sap/') && master_setup.custom_feature?('Ann SAP')
        if fname.to_s.match /^zym_ack/
          OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler.new.delay.process_from_s3 bucket, remote_path, sync_code: 'ANN-ZYM'
        else
          OpenChain::CustomHandler::AnnInc::AnnSapProductHandler.delay.process_from_s3 bucket, remote_path
        end
      elsif command['path'].include? '/_polo_850/'
        OpenChain::CustomHandler::Polo::Polo850VandegriftParser.new.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_850/') && master_setup.custom_feature?("RL 850")
        OpenChain::CustomHandler::Polo::Polo850Parser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include? '/_shoes_po/'
        OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoSpreadsheetHandler.new.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_eddie_po/') && master_setup.custom_feature?("Eddie Bauer Feeds")
        OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_eb_ftz_ack/') && master_setup.custom_feature?("Eddie Bauer Feeds")
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, remote_path, {username:'eddie_ftz_notification',sync_code: OpenChain::CustomHandler::EddieBauer::EddieBauerFtzAsnGenerator::SYNC_CODE,csv_opts:{col_sep:'|'},module_type:'Entry'}
      elsif command['path'].include?('/_eddie_invoice') && master_setup.custom_feature?("Eddie Bauer Feeds")
        OpenChain::CustomHandler::EddieBauer::EddieBauerCommercialInvoiceParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_lenox_product/') && master_setup.custom_feature?('Lenox')
        OpenChain::CustomHandler::Lenox::LenoxProductParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_lenox_po/') && master_setup.custom_feature?('Lenox')
        OpenChain::CustomHandler::Lenox::LenoxPoParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include? '/_polo_tradecard_810'
        OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_jjill_850/') && master_setup.custom_feature?('JJill')
        OpenChain::CustomHandler::JJill::JJill850XmlParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_ecellerate_shipment')
        OpenChain::CustomHandler::EcellerateXmlRouter.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_lands_end_parts/') && master_setup.custom_feature?('Lands End Parts')
        OpenChain::CustomHandler::LandsEnd::LePartsParser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_lands_end_canada_plus/') && master_setup.custom_feature?('Lands End Canada Plus')
        OpenChain::CustomHandler::LandsEnd::LeCanadaPlusProcessor.delay.process_from_s3 bucket, remote_path
      elsif LinkableAttachmentImportRule.find_import_rule(dir.to_s)
        LinkableAttachmentImportRule.delay.process_from_s3 bucket, remote_path, original_filename: fname.to_s, original_path: dir.to_s
      elsif command['path'].include? '/to_chain/'
        ImportedFile.delay.process_integration_imported_file bucket, remote_path, command['path']
      elsif command['path'].include?('/_test_from_msl') && master_setup.custom_feature?('MSL+')
        #prevent errors; don't do anything else
      elsif command['path'].include?('/_siemens_decrypt/') && File.basename(command['path']).to_s.upcase.ends_with?(".DAT.PGP")
        # Need to send the original filename without the added timestamp in it that our file monitoring process adds.
        OpenChain::CustomHandler::Siemens::SiemensDecryptionPassthroughHandler.new.delay.process_from_s3 bucket, remote_path, original_filename: File.basename(command['path'])
      elsif command['path'].include?('/_kewill_exports/') && master_setup.custom_feature?('alliance')
        OpenChain::CustomHandler::KewillExportShipmentParser.new.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_burlington_850/') && master_setup.custom_feature?("Burlington")
        OpenChain::CustomHandler::Burlington::Burlington850Parser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_burlington_856/') && master_setup.custom_feature?("Burlington")
        OpenChain::CustomHandler::Burlington::Burlington856Parser.delay.process_from_s3 bucket, remote_path
      elsif command['path'].include?('/_amersports_856/') && master_setup.custom_feature?("AmerSports")
        OpenChain::CustomHandler::AmerSports::AmerSports856CiLoadParser.delay.process_from_s3 bucket, remote_path
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
