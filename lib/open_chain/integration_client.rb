require 'open_chain/sqs'
require 'open_chain/s3'
require 'open_chain/fenix_parser'
require 'open_chain/custom_handler/ack_file_handler'
require 'open_chain/custom_handler/ann_inc/ann_sap_product_handler'
require 'open_chain/custom_handler/ann_inc/ann_zym_ack_file_handler'
require 'open_chain/custom_handler/ann_inc/ann_order_850_parser'
require 'open_chain/custom_handler/ann_inc/ann_commercial_invoice_xml_parser'
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
require 'open_chain/custom_handler/lumber_liquidators/lumber_shipment_attachment_file_parser'
require 'open_chain/custom_handler/polo_msl_plus_enterprise_handler'
require 'open_chain/custom_handler/polo/polo_850_vandegrift_parser'
require 'open_chain/custom_handler/polo/polo_tradecard_810_parser'
require 'open_chain/custom_handler/shoes_for_crews/shoes_for_crews_po_spreadsheet_handler'
require 'open_chain/custom_handler/shoes_for_crews/shoes_for_crews_po_zip_handler'
require 'open_chain/custom_handler/lands_end/le_parts_parser'
require 'open_chain/custom_handler/lands_end/le_canada_plus_processor'
require 'open_chain/custom_handler/intacct/alliance_day_end_ar_ap_parser'
require 'open_chain/custom_handler/intacct/alliance_check_register_parser'
require 'open_chain/custom_handler/kewill_export_shipment_parser'
require 'open_chain/custom_handler/siemens/siemens_decryption_passthrough_handler'
require 'open_chain/custom_handler/polo/polo_850_parser'
require 'open_chain/custom_handler/ascena/ascena_po_parser'
require 'open_chain/custom_handler/under_armour/under_armour_po_xml_parser'
require 'open_chain/custom_handler/under_armour/under_armour_856_xml_parser'
require 'open_chain/custom_handler/under_armour/ua_article_master_parser'
require 'open_chain/custom_handler/burlington/burlington_850_parser'
require 'open_chain/custom_handler/burlington/burlington_856_parser'
require 'open_chain/custom_handler/amersports/amersports_856_ci_load_parser'
require 'open_chain/custom_handler/talbots/talbots_850_parser'
require 'open_chain/custom_handler/talbots/talbots_856_parser'
require 'open_chain/custom_handler/kewill_entry_parser'
require 'open_chain/custom_handler/ellery/ellery_order_parser'
require 'open_chain/custom_handler/ellery/ellery_856_parser'
require 'open_chain/custom_handler/vandegrift/vandegrift_kewill_customer_activity_report_parser'
require 'open_chain/custom_handler/vandegrift/vandegrift_kewill_accounting_report_5001'

module OpenChain
  class IntegrationClient

    def self.run_schedulable opts = {}
      opts = {'queue_name' => default_integration_queue_name, 'max_message_count' => 500, 'visibility_timeout' => 300}.merge opts
      process_queue opts['queue_name'], max_message_count: opts['max_message_count'], visibility_timeout: opts['visibility_timeout']
    end

    def self.default_integration_queue_name
      MasterSetup.get.system_code
    end

    def self.process_queue queue_name, max_message_count: 500, visibility_timeout: 300
      raise "Queue Name must be provided." if queue_name.blank?
      queue_url = OpenChain::SQS.create_queue queue_name

      messages_processed = 0
      OpenChain::SQS.poll(queue_url, max_message_count: max_message_count, visibility_timeout: visibility_timeout, yield_raw: true) do |m|
        cmd = nil
        begin
          # If any bad json gets in here...we don't want to reprocess the message...just notify about it
          cmd = JSON.parse m.body
        rescue => e
          e.log_me ["SQS Message: #{m.body}"]
        end

        if cmd
          # Any other error we get here, reprocess the message after the visibility timeout occurs
          response = IntegrationClientCommandProcessor.process_command cmd
          process_command_response response, m
        end
        messages_processed += 1
      end

      messages_processed
    end

    def self.process_command_response response, sqs_message
      case response.try(:[], 'response_type').to_s.downcase
      when "remote_file" 
        # Do Nothing...successful processing, which just results in teh message getting removed
      when "shutdown"
        # There's not really much point to a shutdown response with this running via a scheduler,
        # but I suppose it can't hurt either.

        # Throw here is caught by the SQS.poll method as the means to tell it to stop...any messages already processed will
        # be removed from the queue and no more messages will be yielded
        throw :stop_polling
      else
        # The easest thing to do here as a notifiation is to create an error object and use the log_me of it.  We don't want to raise
        # because that will requeue the message - which, if we got response object, means the error was not transient and something unexpected
        # with a file happened and should be reported, not reprocessed.
        StandardError.new(response.try(:[], "message").to_s).log_me ["SQS Message: #{sqs_message.try(:body)}"]
      end
    end
  end

  class IntegrationClientCommandProcessor
    def self.process_command command
      case command.try(:[], 'request_type')
      when 'remote_file'
        return process_remote_file command
      when 'shutdown'
        return {'response_type' => 'shutdown', 'message' => "Shutting Down"}
      else
        return {'response_type'=>'error','message'=>"Unknown command: #{command}"}
      end
    end

    def self.process_remote_file command, total_attempts = 3
      # Even though this process runs in a delayed job queue, we still primarily want to delay()
      # the processing of each job so that each call to the process_remote_file runs quickly.  This
      # is because the processor really needs to make it through processing every message before
      # the message's visibility timeout "expires" and the sqs message goes back on the queue.

      # We're currently setting the visibility timeout per message in such a way that we get at least
      # 1 second per file to process (including any retries that may occur) without exceeding the visibility
      # timeout.

      # The ||'s below are there for legacy continuity while we deploy an update to the software that pushes
      # inbound files to S3/SQS...which will reside on our new ftp server.  Once the old software is removed,
      # we can do away with the legacy checks.
      bucket = command['s3_bucket'].presence || OpenChain::S3.integration_bucket_name
      s3_path = command['s3_path'].presence || command['remote_path']
      original_path = command['original_path'].presence || command['path']

      original_directory, original_filename = Pathname.new(original_path).split
      original_filename = original_filename.to_s

      # Strip any leading or trailing underscores...they're pointless.
      parser_identifier = original_directory.basename.to_s.downcase.sub(/^_/, "").sub(/_$/, "")
      original_directory = original_directory.to_s

      status_msg = 'success'
      response_type = 'remote_file'

      custom_features = Set.new MasterSetup.get.custom_features_list

      if (parser_identifier == "alliance_day_end_invoices") && custom_features.include?('alliance')
        OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser.delay.process_from_s3 bucket, s3_path, original_filename: original_filename
      elsif (parser_identifier == "alliance_day_end_checks") && custom_features.include?('alliance')
        OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser.delay.process_from_s3 bucket, s3_path, original_filename: original_filename
      elsif (parser_identifier == "kewill_entry") && custom_features.include?("Kewill Entries")
        OpenChain::CustomHandler::KewillEntryParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "kewill_statements") && custom_features.include?("Kewill Statements")
        OpenChain::CustomHandler::Vandegrift::KewillStatementParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "ascena_po") && custom_features.include?('Ascena PO')
        OpenChain::CustomHandler::Ascena::AscenaPoParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "ascena_apll_asn") && custom_features.include?('Ascena APLL ASN')
        OpenChain::CustomHandler::Ascena::Apll856Parser.delay.process_from_s3(bucket, s3_path)
      elsif (parser_identifier == "po_xml") && custom_features.include?("Baillie")
        OpenChain::CustomHandler::Baillie::BaillieOrderXmlParser.delay.process_from_s3(bucket, s3_path)
      elsif (parser_identifier == "fenix_invoices") && custom_features.include?('fenix')
        OpenChain::CustomHandler::FenixInvoiceParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "fenix") && (custom_features.include?('fenix') || custom_features.include?("Fenix B3 Files"))
        OpenChain::FenixParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "hm_i1") && custom_features.include?('H&M I1 Interface')
        OpenChain::CustomHandler::Hm::HmI1Interface.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "hm_i2") && custom_features.include?('H&M I2 Interface')
        OpenChain::CustomHandler::Hm::HmI2ShipmentParser.delay(priority: -5).process_from_s3 bucket, s3_path
      elsif (parser_identifier == "kewill_isf") && custom_features.include?('Kewill ISF')
        OpenChain::CustomHandler::KewillIsfXmlParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "gtn_asn_xml") && custom_features.include?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberGtnAsnParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "sap_vendor_xml") && custom_features.include?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberSapVendorXmlParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "sap_po_xml") && custom_features.include?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "sap_article_xml") && custom_features.include?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberSapArticleXmlParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "sap_pir_xml") && custom_features.include?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberSapPirXmlParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "shipment_docs") && custom_features.include?('Lumber SAP')
        OpenChain::CustomHandler::LumberLiquidators::LumberShipmentAttachmentFileParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "ua_article_master") && custom_features.include?('Under Armour Feeds')
        OpenChain::CustomHandler::UnderArmour::UaArticleMasterParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "from_msl") && custom_features.include?('MSL+')
        if original_filename.match /-ack/
          OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, s3_path, sync_code: 'MSLE', username: ['dlombardi','mgrapp','gtung']
        else
          OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.delay.send_and_delete_ack_file_from_s3 bucket, s3_path, original_filename
        end
      elsif (parser_identifier == "csm_sync") && custom_features.include?('CSM Sync')
        OpenChain::CustomHandler::PoloCsmSyncHandler.delay.process_from_s3 bucket, s3_path, original_filename: original_filename
      elsif (parser_identifier == "from_csm") && original_filename.upcase.start_with?("ACK") && custom_features.include?('CSM Sync')
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, s3_path, sync_code: 'csm_product', username: ['rbjork','aditaran']
      elsif (parser_identifier == "efocus_ack") && custom_features.include?("e-Focus Products")
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, s3_path, sync_code: OpenChain::CustomHandler::PoloEfocusProductGenerator::SYNC_CODE, username: ['rbjork']
      elsif (parser_identifier == "from_sap") && custom_features.include?('Ann SAP')
        if original_filename.match /^zym_ack/
          OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler.new.delay.process_from_s3 bucket, s3_path, sync_code: 'ANN-ZYM'
        else
          OpenChain::CustomHandler::AnnInc::AnnSapProductHandler.delay.process_from_s3 bucket, s3_path
        end
      elsif (parser_identifier == "ann_850") && custom_features.include?("Ann Brokerage Feeds")
        OpenChain::CustomHandler::AnnInc::AnnOrder850Parser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "ann_invoice") && custom_features.include?("Ann Brokerage Feeds")
        OpenChain::CustomHandler::AnnInc::AnnCommercialInvoiceXmlParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "polo_850")
        OpenChain::CustomHandler::Polo::Polo850VandegriftParser.new.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "850") && custom_features.include?("RL 850")
        OpenChain::CustomHandler::Polo::Polo850Parser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "shoes_for_crews_po_zip")
        OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoZipHandler.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "shoes_po")
        OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoSpreadsheetHandler.new.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "eddie_po") && custom_features.include?("Eddie Bauer Feeds")
        OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "eb_ftz_ack") && custom_features.include?("Eddie Bauer Feeds")
        OpenChain::CustomHandler::AckFileHandler.new.delay.process_from_s3 bucket, s3_path, {username:'eddie_ftz_notification',sync_code: OpenChain::CustomHandler::EddieBauer::EddieBauerFtzAsnGenerator::SYNC_CODE,csv_opts:{col_sep:'|'},module_type:'Entry'}
      elsif (parser_identifier == "eddie_invoice") && custom_features.include?("Eddie Bauer Feeds")
        OpenChain::CustomHandler::EddieBauer::EddieBauerCommercialInvoiceParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "lenox_product") && custom_features.include?('Lenox')
        OpenChain::CustomHandler::Lenox::LenoxProductParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "lenox_po") && custom_features.include?('Lenox')
        OpenChain::CustomHandler::Lenox::LenoxPoParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "polo_tradecard_810")
        OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "jjill_850") && custom_features.include?('JJill')
        OpenChain::CustomHandler::JJill::JJill850XmlParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "ecellerate_shipment")
        OpenChain::CustomHandler::EcellerateXmlRouter.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "lands_end_parts") && custom_features.include?('Lands End Parts')
        OpenChain::CustomHandler::LandsEnd::LePartsParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "lands_end_canada_plus") && custom_features.include?('Lands End Canada Plus')
        OpenChain::CustomHandler::LandsEnd::LeCanadaPlusProcessor.delay.process_from_s3 bucket, s3_path
      elsif (original_directory.include?("to_chain/"))
        ImportedFile.delay.process_integration_imported_file bucket, s3_path, original_path
      elsif (parser_identifier == "test_from_msl") && custom_features.include?('MSL+')
        #prevent errors; don't do anything else
      elsif (parser_identifier == "siemens_decrypt") && original_filename.to_s.upcase.ends_with?(".DAT.PGP")
        # Need to send the original filename without the added timestamp in it that our file monitoring process adds.
        OpenChain::CustomHandler::Siemens::SiemensDecryptionPassthroughHandler.new.delay.process_from_s3 bucket, s3_path, original_filename: original_filename
      elsif (parser_identifier == "kewill_exports") && custom_features.include?('Kewill Exports')
        OpenChain::CustomHandler::KewillExportShipmentParser.new.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "ua_po_xml") && custom_features.include?('Under Armour Feeds')
        OpenChain::CustomHandler::UnderArmour::UnderArmourPoXmlParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "ua_856_xml") && custom_features.include?('Under Armour Feeds')
        OpenChain::CustomHandler::UnderArmour::UnderArmour856XmlParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "burlington_850") && custom_features.include?("Burlington")
        OpenChain::CustomHandler::Burlington::Burlington850Parser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "burlington_856") && custom_features.include?("Burlington")
        OpenChain::CustomHandler::Burlington::Burlington856Parser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "amersports_856") && custom_features.include?("AmerSports")
        OpenChain::CustomHandler::AmerSports::AmerSports856CiLoadParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "talbots_850") && custom_features.include?("Talbots")
        OpenChain::CustomHandler::Talbots::Talbots850Parser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "talbots_856") && custom_features.include?("Talbots")
        OpenChain::CustomHandler::Talbots::Talbots856Parser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "ellery_po") && custom_features.include?("Ellery")
        OpenChain::CustomHandler::Ellery::ElleryOrderParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "ellery_856") && custom_features.include?("Ellery")
        OpenChain::CustomHandler::Ellery::Ellery856Parser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "vfi_kewill_customer_activity_report")
        OpenChain::CustomHandler::Vandegrift::VandegriftKewillCustomerActivityReportParser.delay.process_from_s3 bucket, s3_path
      elsif (parser_identifier == "arprfsub")
        OpenChain::CustomHandler::Vandegrift::VandegriftKewillAccountingReport5001.delay.process_from_s3 bucket, s3_path
      else
        # This should always be the very last thing to process..that's why it's in the else
        if LinkableAttachmentImportRule.find_import_rule(original_directory)
          LinkableAttachmentImportRule.delay.process_from_s3 bucket, s3_path, original_filename: original_filename, original_path: original_directory
        else
          response_type = 'error'
          status_msg = "Can't figure out what to do for path #{original_path}"
        end
      end

      return {'response_type'=>response_type,(response_type=='error' ? 'message' : 'status')=>status_msg}
    rescue => e
      error_message = {'response_type'=>"error", "message" => e.message}

      return error_message unless Rails.env.production?

      total_attempts -= 1
      if total_attempts > 0
        sleep 0.25
        retry
      else
        return error_message
      end
    end

  end
end
