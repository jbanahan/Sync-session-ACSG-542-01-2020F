require 'open_chain/integration_client'
require 'open_chain/s3'

describe OpenChain::IntegrationClient do
  let! (:master_setup) { stub_master_setup }
  let (:system_code) { master_setup.system_code }

  subject { described_class }

  describe "process_queue" do

    it 'queries specified queue, processes messages from it and then stops' do
      response1 = instance_double("Aws::Sqs::Types::ReceiveMessageResult")

      parser_message = instance_double("Aws::Sqs::Types::Message")
      allow(parser_message).to receive(:body).and_return({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}.to_json)
      allow(response1).to receive(:messages).and_return [parser_message]

      expect(OpenChain::SQS).to receive(:get_queue_url).with(system_code).and_return "queue.url"
      expect(OpenChain::SQS).to receive(:poll).with("queue.url", max_message_count: 3, visibility_timeout: 5, yield_raw: true).and_yield(parser_message)

      remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
      expect(OpenChain::IntegrationClientCommandProcessor).to receive(:process_remote_file).and_return(remote_file_response)

      expect(subject.process_queue system_code, max_message_count: 3, visibility_timeout: 5).to eq 1
    end

    it 'queries specified queue, creates it if not found, then processes messages from it and then stops' do
      response1 = instance_double("Aws::Sqs::Types::ReceiveMessageResult")

      parser_message = instance_double("Aws::Sqs::Types::Message")
      allow(parser_message).to receive(:body).and_return({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}.to_json)
      allow(response1).to receive(:messages).and_return [parser_message]

      expect(OpenChain::SQS).to receive(:get_queue_url).with(system_code).and_return nil
      expect(OpenChain::SQS).to receive(:create_queue).with(system_code).and_return "queue.url"
      expect(OpenChain::SQS).to receive(:poll).with("queue.url", max_message_count: 3, visibility_timeout: 5, yield_raw: true).and_yield(parser_message)

      remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
      expect(OpenChain::IntegrationClientCommandProcessor).to receive(:process_remote_file).and_return(remote_file_response)

      expect(subject.process_queue system_code, max_message_count: 3, visibility_timeout: 5).to eq 1
    end

    it 'does not rescue errors from process command' do
      expect(OpenChain::SQS).to receive(:get_queue_url).and_return "queue.url"

      parser_message = instance_double("Aws::Sqs::Types::Message")
      allow(parser_message).to receive(:body).and_return({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}.to_json)

      #Just mock out the retrieve queue messages call here, since it's not needed to test message handling
      expect(OpenChain::SQS).to receive(:poll).and_yield parser_message
      expect(OpenChain::IntegrationClientCommandProcessor).to receive(:process_command).with(JSON.parse(parser_message.body)).and_raise "Error"
      
      expect { subject.process_queue "queue.url" }.to raise_error "Error"
    end

    it "errors if queue name is blank" do
      expect { subject.process_queue ''}.to raise_error "Queue Name must be provided."
    end

    it "catches and handles bad json" do
      expect(OpenChain::SQS).to receive(:get_queue_url).and_return "queue.url"

      parser_message = instance_double("Aws::Sqs::Types::Message")
      allow(parser_message).to receive(:body).and_return("{badjson}")

      #Just mock out the retrieve queue messages call here, since it's not needed to test message handling
      expect(OpenChain::SQS).to receive(:poll).and_yield parser_message

      expect(subject.process_queue "queue.url").to eq 1
      e = ErrorLogEntry.first
      expect(e).not_to be_nil
      expect(e.additional_messages_json).to include "SQS Message:"
    end
  end

  describe "run_schedulable" do
    it "uses master setup to get queue name and defaults to 500 max messages" do
      expect(OpenChain::IntegrationClient).to receive(:process_queue).with system_code, max_message_count: 500, visibility_timeout: 300
      subject.run_schedulable
    end

    it "uses provided parameters" do
      expect(OpenChain::IntegrationClient).to receive(:process_queue).with 'queue', max_message_count: 5, visibility_timeout: 10
      subject.run_schedulable({'queue_name' => 'queue', 'max_message_count' => 5, 'visibility_timeout' => 10})
    end
  end

  describe "default_integration_queue_name" do
    it "uses system code as default queue name" do
      expect(subject.default_integration_queue_name).to eq system_code
    end
  end

  describe "process_command_response" do
    it "does nothing if response type is 'remote_file'" do
      subject.process_command_response({'response_type' => "ReMoTe_File"}, nil)
    end

    it "throws :stop_polling if response_type is 'shutdown'" do
      expect {subject.process_command_response({'response_type' => "shutdown"}, nil) }.to throw_symbol(:stop_polling)
    end

    it "logs error for any other case" do
      msg = instance_double("Aws::Sqs::Types::Message")
      expect(msg).to receive(:body).and_return "Message Body"

      expect_any_instance_of(StandardError).to receive(:log_me) do |instance, param|
        expect(instance.message).to eq "Error Message"
        expect(param).to eq ["SQS Message: Message Body"]
      end

      subject.process_command_response({'response_type' => "error", "message" => "Error Message"}, msg)
    end
  end
end

describe OpenChain::IntegrationClientCommandProcessor do

  def do_parser_test custom_feature, parser_class, original_path, original_filename: nil
    expect(master_setup).to receive(:custom_features_list).and_return Array.wrap(custom_feature)
    p = class_double(parser_class.to_s)
    expect(parser_class).to receive(:delay).and_return p
    if block_given?
      yield p
    else
      if original_filename
        expect(p).to receive(:process_from_s3).with "bucket", '12345', original_filename: original_filename
      else
        expect(p).to receive(:process_from_s3).with "bucket", '12345'
      end
    end
    cmd = {'request_type'=>'remote_file','original_path'=>original_path,'s3_bucket'=>'bucket', 's3_path'=>'12345'}
    expect(subject.process_command(cmd)).to eq(success_hash)
  end

  subject {described_class}

  let! (:master_setup) { 
    ms = stub_master_setup 
    allow(ms).to receive(:custom_features_list).and_return []
    ms
  }
  let (:success_hash) { {'response_type'=>'remote_file','status'=>'success'} }

  describe "process_remote_file" do
    it "handles raised errors by returning an error response" do
      # This is just the first method call that's easy to mock out and raise something in the method, could be
      # replaced by anything else.
      cmd = {'request_type'=>'remote_file','original_path'=>'file.txt','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(cmd).to receive(:[]).and_raise "Error"
      expect(subject.process_remote_file(cmd)).to eq({'response_type'=>'error','message'=>"Error"})
    end
  end

  describe "process_command", :disable_delayed_jobs do
    it 'should create linkable attachment if linkable attachment rule match' do
      LinkableAttachmentImportRule.create!(:path=>'/path/to',:model_field_uid=>'prod_uid')
      cmd = {'request_type'=>'remote_file','original_path'=>'/path/to/this.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(LinkableAttachmentImportRule).to receive(:delay).and_return LinkableAttachmentImportRule
      expect(LinkableAttachmentImportRule).to receive(:process_from_s3).with("bucket",'12345', original_filename: 'this.csv', original_path: '/path/to')
      expect(subject.process_command(cmd)).to eq(success_hash)
    end

    it "processes imported files" do
      cmd = {'request_type'=>'remote_file','original_path'=>'/test/to_chain/module/file.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(ImportedFile).to receive(:delay).and_return ImportedFile
      expect(ImportedFile).to receive(:process_integration_imported_file).with("bucket", '12345', '/test/to_chain/module/file.csv')
      expect(subject.process_command(cmd)).to eq(success_hash)
    end

    it 'should return error if not imported_file or linkable_attachment' do
      expect(LinkableAttachmentImportRule).to receive(:find_import_rule).and_return(nil)
      cmd = {'request_type'=>'remote_file','original_path'=>'/some/invalid/path','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(subject.process_command(cmd)).to eq({'response_type'=>'error','message'=>"Can't figure out what to do for path /some/invalid/path"})
    end

    it "handles legacy style sqs messages" do 
      expect(master_setup).to receive(:custom_features_list).and_return ['Ellery']
      p = class_double("OpenChain::CustomHandler::Ellery::ElleryOrderParser")
      expect(OpenChain::CustomHandler::Ellery::ElleryOrderParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/ellery_po/file.csv', 'remote_path'=>'12345'}
      expect(subject.process_command(cmd)).to eq(success_hash)
    end

    it 'should return error if bad request type' do
      cmd = {'something_bad'=>'crap'}
      expect(subject.process_command(cmd)).to eq({'response_type'=>'error','message'=>"Unknown command: #{cmd}"})
    end

    context "ascena" do
      it "sends data to Ascena PO parser" do
        do_parser_test('Ascena PO', OpenChain::CustomHandler::Ascena::AscenaPoParser, '/_ascena_po/a.csv')
      end
      it "should send data to ascena apll 856 parser if path contains _ascena_apll_asn" do
        do_parser_test('Ascena APLL ASN', OpenChain::CustomHandler::Ascena::Apll856Parser, '/_ascena_apll_asn/a.txt')
      end
    end
    context "baillie" do
      it "should send data to the baillie order xml parser if the path contains /_po_xml and master setup includes Baillie" do
        do_parser_test('Baillie', OpenChain::CustomHandler::Baillie::BaillieOrderXmlParser, '/baillie/_po_xml/a.xml')
      end
    end
    context "hm" do
      it "should send data to H&M I1 Interface if feature enabled and path contains _hm_i1" do
        do_parser_test('H&M I1 Interface', OpenChain::CustomHandler::Hm::HmI1Interface, '/_hm_i1/a.csv')
      end

      it "should send data to H&M I2 Interface if feature enabled and path contains _hm_i2" do
        # Standard test won't work because of the priority param used below
        expect(master_setup).to receive(:custom_features_list).and_return ['H&M I2 Interface']
        expect(OpenChain::CustomHandler::Hm::HmI2ShipmentParser).to receive(:delay).with(priority: -5).and_return OpenChain::CustomHandler::Hm::HmI2ShipmentParser
        expect(OpenChain::CustomHandler::Hm::HmI2ShipmentParser).to receive(:process_from_s3).with("bucket", '12345')
        cmd = {'request_type'=>'remote_file','original_path'=>'/_hm_i2/a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(subject.process_command(cmd)).to eq(success_hash)
      end

      it "handles H&M I2 drawbacks" do
        do_parser_test('H&M I2 Interface', OpenChain::CustomHandler::Hm::HmI2DrawbackParser, '/hm_i2_drawback/file.csv')
      end

      it "handles H&M Purolator drawbacks" do
        do_parser_test('H&M Purolator Interface', OpenChain::CustomHandler::Hm::HmPurolatorDrawbackParser, '/hm_purolator_drawback/file.csv')
      end

      it "should send data to H&M i977 parser if feature enabled and path contains _hm_i977" do
        expect(master_setup).to receive(:custom_features_list).and_return ['H&M Interfaces']
        expect(OpenChain::CustomHandler::Hm::HmI977Parser).to receive(:delay).and_return OpenChain::CustomHandler::Hm::HmI977Parser
        expect(OpenChain::CustomHandler::Hm::HmI977Parser).to receive(:process_from_s3).with("bucket", '12345')
        cmd = {'request_type'=>'remote_file','original_path'=>'/_hm_i977/a.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(subject.process_command(cmd)).to eq(success_hash)
      end

      it "should send data to H&M i978 parser if feature enabled and path contains _hm_i978" do
        expect(master_setup).to receive(:custom_features_list).and_return ['H&M Interfaces']
        expect(OpenChain::CustomHandler::Hm::HmI978Parser).to receive(:delay).with(priority: -5).and_return OpenChain::CustomHandler::Hm::HmI978Parser
        expect(OpenChain::CustomHandler::Hm::HmI978Parser).to receive(:process_from_s3).with("bucket", '12345')
        cmd = {'request_type'=>'remote_file','original_path'=>'/_hm_i978/a.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(subject.process_command(cmd)).to eq(success_hash)
      end
    end
    context "lands_end" do
      it "should send data to Lands End Parts parser" do
        do_parser_test('Lands End Parts', OpenChain::CustomHandler::LandsEnd::LePartsParser, '/_lands_end_parts/a.xml')
      end
      it "sends data to Lands End Canada Plus processor" do
        do_parser_test('Lands End Canada Plus', OpenChain::CustomHandler::LandsEnd::LeCanadaPlusProcessor, '/_lands_end_canada_plus/a.zip')
      end
    end
    context "LT" do
      it "handles orders" do
        do_parser_test('LT', OpenChain::CustomHandler::Lt::Lt850Parser, '/lt_850/file.csv')
      end
      it "handles shipments" do
        do_parser_test('LT', OpenChain::CustomHandler::Lt::Lt856Parser, '/lt_856/file.csv')
      end
    end
    context "jjill" do
      it "should send data to J Jill 850 parser" do
        do_parser_test('JJill', OpenChain::CustomHandler::JJill::JJill850XmlParser, '/_jjill_850/a.xml')
      end
    end

    context "lenox" do
      it "should send data to lenox prodct parser if feature enabled and path contains _lenox_product" do
        do_parser_test('Lenox', OpenChain::CustomHandler::Lenox::LenoxProductParser, '/_lenox_product/a.csv')
      end

      it "should send data to lenox po parser if feature enabled and path contains _lenox_po" do
        do_parser_test('Lenox', OpenChain::CustomHandler::Lenox::LenoxPoParser, '/_lenox_po/a.csv')
      end
    end

    context "ann_inc" do
      it "should send data to Ann Inc SAP Product Handler if feature enabled and path contains _from_sap" do
        do_parser_test('Ann SAP', OpenChain::CustomHandler::AnnInc::AnnSapProductHandler, '/_from_sap/a.csv')
      end

      it "should send data to Ack Handler if SAP enabled and path containers _from_sap and file starts with zym_ack" do
        do_parser_test('Ann SAP', OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler, '/_from_sap/zym_ack.a.csv') do |parser|
          expect(parser).to receive(:process_from_s3).with "bucket", '12345', {:sync_code => 'ANN-ZYM'}
        end
      end

      it "handles ann 850 files" do
        do_parser_test('Ann Brokerage Feeds', OpenChain::CustomHandler::AnnInc::AnnOrder850Parser, '/_ann_850/file.edi')
      end

      it "handles ann invoice xml files" do
        do_parser_test('Ann Brokerage Feeds', OpenChain::CustomHandler::AnnInc::AnnCommercialInvoiceXmlParser, '/_ann_invoice/file.xml')
      end

      it "handles e-Focus PDM product ack files" do
        do_parser_test('Ann Inc', OpenChain::CustomHandler::AckFileHandler, '/ann_efocus_products_ack/efocus_ack.csv') do |parser|
          expect(parser).to receive(:process_from_s3).with "bucket", '12345', {:sync_code => 'ANN-PDM', mailing_list_code: "efocus_products_ack", email_warnings: false}
        end
      end
    end

    context "eddie_bauer" do
      it "should send ack files to ack parser for _eb_ftz_ack" do
        do_parser_test('Eddie Bauer Feeds', OpenChain::CustomHandler::AckFileHandler, '/_eb_ftz_ack/file.txt') do |parser|
          expect(parser).to receive(:process_from_s3).with "bucket", '12345', {username:'eddie_ftz_notification',sync_code: OpenChain::CustomHandler::EddieBauer::EddieBauerFtzAsnGenerator::SYNC_CODE,csv_opts:{col_sep:'|'},module_type:'Entry'}
        end
      end
      it "should send data to eddie bauer po parser for _eddie_po" do
        do_parser_test('Eddie Bauer Feeds', OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser, '/_eddie_po/file.txt')
      end

      it "handles Eddie invoices" do
        do_parser_test('Eddie Bauer Feeds', OpenChain::CustomHandler::EddieBauer::EddieBauerCommercialInvoiceParser, '/_eddie_invoice/file.txt')
      end
    end

    context "lumber_liquidators" do
      it "should send data to LL GTN ASN parser" do
        do_parser_test('Lumber SAP', OpenChain::CustomHandler::LumberLiquidators::LumberGtnAsnParser, '/_gtn_asn_xml/x.xml')
      end
      it "should send data to LL PO parser" do
        do_parser_test('Lumber SAP', OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlParser, '/_sap_po_xml/x.xml')
      end
      it "should send data to LL PIR parser" do
        do_parser_test('Lumber SAP', OpenChain::CustomHandler::LumberLiquidators::LumberSapPirXmlParser, '/_sap_pir_xml/x.xml')
      end

      it "should send data to LL Article parser" do
        do_parser_test('Lumber SAP', OpenChain::CustomHandler::LumberLiquidators::LumberSapArticleXmlParser, '/_sap_article_xml/x.xml')
      end
      it "should send data to LL Vendor parser" do
        do_parser_test('Lumber SAP', OpenChain::CustomHandler::LumberLiquidators::LumberSapVendorXmlParser, '/_sap_vendor_xml/x.xml')
      end
      it "should send data to LL shipment attachment parser" do
        do_parser_test('Lumber SAP', OpenChain::CustomHandler::LumberLiquidators::LumberShipmentAttachmentFileParser, '/shipment_docs/x.zip')
      end

      it "should send data to Lumber booking confirmation parser" do
        do_parser_test('Lumber SAP', OpenChain::CustomHandler::LumberLiquidators::LumberBookingConfirmationXmlParser, '/ll_booking_confirmation/file.xml')
      end

      it "should send data to Lumber shipment plan parser" do
        do_parser_test('Lumber SAP', OpenChain::CustomHandler::LumberLiquidators::LumberShipmentPlanXmlParser, '/ll_shipment_plan/file.xml')
      end
    end

    context "Ralph Lauren" do

      it "should not raise errors on test files" do
        ack = double("ack_file")
        cmd = {'request_type'=>'remote_file','original_path'=>'/test_from_msl/a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect{subject.process_command(cmd)}.to_not raise_error
      end

      it 'should process CSM Acknowledgements' do
        do_parser_test('CSM Sync', OpenChain::CustomHandler::AckFileHandler, '/_from_csm/ACK-file.csv') do |parser|
          expect(parser).to receive(:process_from_s3).with "bucket", '12345', {sync_code: 'csm_product', mailing_list_code: "csm_products_ack"}
        end
      end

      it "should send to VF 850 Parser" do
        do_parser_test("", OpenChain::CustomHandler::Polo::Polo850VandegriftParser, '/_polo_850/file.xml')
      end

      it "should send efocus ack files to ack handler" do
        do_parser_test("e-Focus Products", OpenChain::CustomHandler::AckFileHandler, '/_efocus_ack/file.csv') do |parser|
          expect(parser).to receive(:process_from_s3).with "bucket", '12345', {:sync_code => OpenChain::CustomHandler::PoloEfocusProductGenerator::SYNC_CODE, mailing_list_code: "efocus_products_ack"}
        end
      end

      it "should send Tradecard 810 files to handler" do
        do_parser_test("", OpenChain::CustomHandler::Polo::PoloTradecard810Parser, '/_polo_tradecard_810/file.csv')
      end

      it "handles polo 850 files" do
        do_parser_test("RL 850", OpenChain::CustomHandler::Polo::Polo850Parser, '/polo/_850/file.dat')
      end

      it "handles ua po files" do
        do_parser_test('Under Armour Feeds', OpenChain::CustomHandler::UnderArmour::UnderArmourPoXmlParser, '/_ua_po_xml/file.xml')
      end

      it 'should send data to CSM Sync custom handler if feature enabled and path contains _csm_sync' do
        do_parser_test('CSM Sync', OpenChain::CustomHandler::PoloCsmSyncHandler, '/_csm_sync/a.xls', original_filename: 'a.xls')
      end

      it "handles Polo Global Frontend product files" do
        do_parser_test("", OpenChain::CustomHandler::Polo::PoloGlobalFrontEndProductParser, "/gfe_products/file.txt")
      end

      it "handles AX product ack files" do
        do_parser_test('CSM Sync', OpenChain::CustomHandler::AckFileHandler, '/ax_products_ack/file.txt') do |parser|
          expect(parser).to receive(:process_from_s3).with "bucket", '12345', {sync_code: 'AX', mailing_list_code: "ax_products_ack"}
        end
      end
    end

    context "vandegrift" do
      it 'should send data to Kewill parser if Kewill ISF is enabled and path contains _kewill_isf' do
        do_parser_test('Kewill ISF', OpenChain::CustomHandler::KewillIsfXmlParser, '/_kewill_isf/x.y')
      end

      it 'should send data to Fenix parser if Fenix B3 Files custom feature enabled' do
        do_parser_test("Fenix B3 Files", OpenChain::FenixParser, '/_fenix/x.y')
      end

      it 'should send data to Fenix invoice parser if feature enabled and path contains _fenix_invoices' do
        do_parser_test("fenix", OpenChain::CustomHandler::FenixInvoiceParser, '/_fenix_invoices/x.y')
      end

      it 'should send data to Alliance Day End Invoice parser if custom feature enabled and path contains _alliance_day_end_invoices' do
        do_parser_test("alliance", OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser, '/_alliance_day_end_invoices/x.y', original_filename: "x.y")
      end

      it 'should send data to Alliance Day End Check parser if custom feature enabled and path contains _alliance_day_end_invoices' do
        do_parser_test("alliance", OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser, '/_alliance_day_end_checks/x.y', original_filename: "x.y")
      end

      it 'handles kewill export files' do
        do_parser_test("Kewill Exports", OpenChain::CustomHandler::KewillExportShipmentParser, '/_kewill_exports/file.dat')
      end

      it "handles kewill entries" do
        do_parser_test('Kewill Entries', OpenChain::CustomHandler::KewillEntryParser, '/_kewill_entry/file.json')
      end

      it "handles kewill statements" do
        do_parser_test('Kewill Statements', OpenChain::CustomHandler::Vandegrift::KewillStatementParser, '/kewill_statements/file.json')
      end

      it "handles vandegrift customer activity reports" do
        do_parser_test("alliance", OpenChain::CustomHandler::Vandegrift::VandegriftKewillCustomerActivityReportParser, '/vfi_kewill_customer_activity_report/file.rpt')
      end

      it "handles vandegrift kewill accounting report 5001" do
        do_parser_test("alliance", OpenChain::CustomHandler::Vandegrift::VandegriftKewillAccountingReport5001, '/arprfsub/file.rpt')
      end
      
      it "handles Kewill Tariff files" do
        do_parser_test("Kewill Entries", OpenChain::CustomHandler::Vandegrift::KewillTariffClassificationsParser, "/kewill_tariffs/file.json")
      end

      it "handles Tariff Upload files" do
        do_parser_test("Tariff Upload", TariffLoader, "/tariff_file/file.zip")
      end

      it "handles Maersk Cargowise entry files" do
        do_parser_test("Maersk Cargowise Feeds", OpenChain::CustomHandler::Vandegrift::MaerskCargowiseEntryFileParser, '/maersk_cw_universal_shipment/file.xml')
      end

      it "handles Maersk Cargowise broker invoice files" do
        do_parser_test("Maersk Cargowise Feeds", OpenChain::CustomHandler::Vandegrift::MaerskCargowiseBrokerInvoiceFileParser, '/maersk_cw_universal_transaction/file.xml')
      end

      it "handles Maersk Cargowise event files" do
        do_parser_test("Maersk Cargowise Feeds", OpenChain::CustomHandler::Vandegrift::MaerskCargowiseEventFileParser, '/maersk_cw_universal_event/file.xml')
      end

      it "handles Kewill Customer files" do
        do_parser_test("Kewill Entries", OpenChain::CustomHandler::Vandegrift::KewillCustomerParser, "/kewill_customers/file.json")
      end
    end

    context "foot_locker" do
      it "sends data to FootLocker HTS Parser" do
        do_parser_test('Foot Locker Parts', OpenChain::CustomHandler::FootLocker::FootLockerHtsParser, 'footlocker_hts/a.csv')
      end
    end

    context "under_armour" do
      it "sends data to UA Article Master Parser" do
        do_parser_test('Under Armour Feeds', OpenChain::CustomHandler::UnderArmour::UaArticleMasterParser, '/_ua_article_master/a.xml')
      end

      it "handles ua 856 files" do
        do_parser_test('Under Armour Feeds', OpenChain::CustomHandler::UnderArmour::UnderArmour856XmlParser, '/_ua_856_xml/file.xml')
      end
    end

    context "shoes for crews" do
      it "should send Shoes For Crews PO files to handler" do
        do_parser_test("", OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoSpreadsheetHandler, '/_shoes_po/file.csv')
      end

      it "sends Shoes For Crews zip files to handler" do
        do_parser_test("", OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoZipHandler, '/_shoes_for_crews_po_zip/file.zip')
      end
    end

    context "burlington" do
      it "handles burlington 850 files" do
        do_parser_test('Burlington', OpenChain::CustomHandler::Burlington::Burlington850Parser, '/_burlington_850/file.dat')
      end

      it "handles burlington 856 files" do
        do_parser_test('Burlington', OpenChain::CustomHandler::Burlington::Burlington856Parser, '/_burlington_856/file.dat')
      end
    end

    context "amersports" do
      it "handles amersports 856 files" do
        do_parser_test('AmerSports', OpenChain::CustomHandler::AmerSports::AmerSports856CiLoadParser, '/_amersports_856/file.dat')
      end
    end

    context "siemens" do
      it "handles Siemens .dat.pgp files" do
        do_parser_test("", OpenChain::CustomHandler::Siemens::SiemensDecryptionPassthroughHandler, '/_siemens_decrypt/file.dat.pgp', original_filename: 'file.dat.pgp')
      end
    end

    context "talbots" do
      it "handles Talbots 850s" do
        do_parser_test('Talbots', OpenChain::CustomHandler::Talbots::Talbots850Parser, '/_talbots_850/file.edi')
      end

      it "handles Talbots 856s" do
        do_parser_test('Talbots', OpenChain::CustomHandler::Talbots::Talbots856Parser, '/_talbots_856/file.edi')
      end
    end

    context "ellery" do
      it "handles ellery orders" do
        do_parser_test("Ellery", OpenChain::CustomHandler::Ellery::ElleryOrderParser, '/ellery_po/file.csv')
      end

      it "handles ellery 856s" do
        do_parser_test("Ellery", OpenChain::CustomHandler::Ellery::Ellery856Parser, '/ellery_856/file.csv')
      end
    end

    context "pvh" do
      it "handles PVH GTN Order files" do
        do_parser_test("PVH Feeds", OpenChain::CustomHandler::Pvh::PvhGtnOrderXmlParser, '/pvh_gtn_order_xml/file.xml')
      end

      it "handles PVH GTN Invoice files" do
        do_parser_test("PVH Feeds", OpenChain::CustomHandler::Pvh::PvhGtnInvoiceXmlParser, '/pvh_gtn_invoice_xml/file.xml')
      end

      it "handles PVH GTN Asn files" do
        do_parser_test("PVH Feeds", OpenChain::CustomHandler::Pvh::PvhGtnAsnXmlParser, '/pvh_gtn_asn_xml/file.xml')
      end
    end

    context "ecellerate" do
      it "handles eCellerate shipment xml files" do
        do_parser_test("eCellerate", OpenChain::CustomHandler::Descartes::DescartesBasicShipmentXmlParser, '/ecellerate_shipment/file.xml')
      end
    end

    context "advan" do
      it "handles Advance Prep 7501 files" do
        do_parser_test("Advance 7501", OpenChain::CustomHandler::Advance::AdvancePrep7501ShipmentParser, '/advan_prep_7501/file.xml')
      end
    end

    context "Generic GTN Feeds" do
      it "handles Generic GTN Invoice files" do
        do_parser_test("Generic GTN XML", OpenChain::CustomHandler::GtNexus::GenericGtnInvoiceXmlParser, '/gtn_invoice_xml/file.xml')
      end
    end

    context "Amazon Parts" do
      it "handles Amazon Parts files" do
        do_parser_test("Amazon Parts", OpenChain::CustomHandler::Amazon::AmazonProductParserBroker, '/amazon_parts/file.csv')
      end
    end
  end
end