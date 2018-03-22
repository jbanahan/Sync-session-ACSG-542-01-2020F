require 'spec_helper'
require 'open_chain/integration_client'
require 'open_chain/s3'

describe OpenChain::IntegrationClient do
  let! (:master_setup) { stub_master_setup }
  let (:system_code) { master_setup.system_code }

  describe "process_queue" do

    it 'creates specified queue, processes messages from it and then stops' do
      response1 = instance_double("Aws::Sqs::Types::ReceiveMessageResult")

      parser_message = instance_double("Aws::Sqs::Types::Message")
      allow(parser_message).to receive(:body).and_return({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}.to_json)
      allow(parser_message).to receive(:attributes).and_return({"SentTimestamp" => 10.seconds.ago})
      allow(response1).to receive(:messages).and_return [parser_message]

      response2 = instance_double("Aws::Sqs::Types::ReceiveMessageResult")

      parser_message_2 = instance_double("Aws::Sqs::Types::Message")
      allow(parser_message_2).to receive(:body).and_return({:request_type=>'shutdown'}.to_json)
      allow(parser_message_2).to receive(:attributes).and_return({"SentTimestamp" => 3.seconds.ago})
      allow(response2).to receive(:messages).and_return [parser_message_2]

      expect(OpenChain::SQS).to receive(:create_queue).with(system_code).and_return "queue.url"
      allow(OpenChain::SQS).to receive(:visible_message_count).and_return 1, 1, 0
      expect(OpenChain::SQS).to receive(:retrieve_messages).with("queue.url", {max_number_of_messages: 10, wait_time_seconds: 0, visibility_timeout: 63, attribute_names: [:SentTimestamp]}).and_return response1
      expect(OpenChain::SQS).to receive(:retrieve_messages).with("queue.url", {max_number_of_messages: 10, wait_time_seconds: 0, visibility_timeout: 63, attribute_names: [:SentTimestamp]}).and_return response2

      remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
      expect(OpenChain::IntegrationClientCommandProcessor).to receive(:process_remote_file).and_return(remote_file_response)
      expect(OpenChain::SQS).to receive(:delete_message).with("queue.url", parser_message)
      expect(OpenChain::SQS).to receive(:delete_message).with("queue.url", parser_message_2)

      expect(OpenChain::IntegrationClient.process_queue system_code, 3).to eq 2
    end

    it "respects the max message count" do
      expect(OpenChain::SQS).to receive(:create_queue).and_return "queue.url"

      # Set the visible count so it shows more messages available than we actually want to handle
      allow(OpenChain::SQS).to receive(:visible_message_count).and_return 1, 1

      response1 = instance_double("Aws::Sqs::Types::ReceiveMessageResult")
      parser_message = instance_double("Aws::Sqs::Types::Message")
      allow(parser_message).to receive(:body).and_return({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}.to_json)
      allow(parser_message).to receive(:attributes).and_return({"SentTimestamp" => 10.seconds.ago})
      allow(response1).to receive(:messages).and_return [parser_message]

      expect(OpenChain::SQS).to receive(:retrieve_messages).with("queue.url", {max_number_of_messages: 10, wait_time_seconds: 0, visibility_timeout: 61, attribute_names: [:SentTimestamp]}).and_return response1

      remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
      expect(OpenChain::IntegrationClientCommandProcessor).to receive(:process_remote_file).and_return(remote_file_response)
      expect(OpenChain::SQS).to receive(:delete_message).with("queue.url", parser_message)

      expect(OpenChain::IntegrationClient.process_queue system_code, 1).to eq 1
    end

    it 'rescues errors from process command' do
      expect(OpenChain::SQS).to receive(:create_queue).and_return "queue.url"

      parser_message = instance_double("Aws::Sqs::Types::Message")
      allow(parser_message).to receive(:body).and_return({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}.to_json)

      #Just mock out the retrieve queue messages call here, since it's not needed to test message handling
      expect(OpenChain::IntegrationClient).to receive(:retrieve_queue_messages).with('queue.url', 500).and_return [parser_message]
      expect(OpenChain::IntegrationClientCommandProcessor).to receive(:process_command).with(JSON.parse(parser_message.body)).and_raise "Error"
      expect(OpenChain::SQS).to receive(:delete_message).with("queue.url", parser_message)

      OpenChain::IntegrationClient.process_queue "queue.url"
      expect(ErrorLogEntry.last.additional_messages).to eq ["SQS Message: #{parser_message.body}"]
    end

    it "errors if queue name is blank" do
      expect {OpenChain::IntegrationClient.process_queue ''}.to raise_error "Queue Name must be provided."
    end
  end

  describe "run_schedulable" do
    it "uses master setup to get queue name and defaults to 500 max messages" do
      expect(OpenChain::IntegrationClient).to receive(:process_queue).with system_code, 500
      OpenChain::IntegrationClient.run_schedulable
    end

    it "uses provided parameters" do
      expect(OpenChain::IntegrationClient).to receive(:process_queue).with 'queue', 5
      OpenChain::IntegrationClient.run_schedulable({'queue_name' => 'queue', 'max_message_count' => 5})
    end
  end

  describe "default_integration_queue_name" do
    subject { described_class }
    it "uses system code as default queue name" do
      expect(subject.default_integration_queue_name).to eq system_code
    end
  end
end

describe OpenChain::IntegrationClientCommandProcessor do

  let! (:master_setup) { 
    ms = stub_master_setup 
    allow(ms).to receive(:custom_features_list).and_return []
    ms
  }
  let (:success_hash) { {'response_type'=>'remote_file','status'=>'success'} }

  context 'request type: remote_file', :disable_delayed_jobs do
    context "ecellerate" do
      it "should send data to eCellerate router" do
        expect(OpenChain::CustomHandler::EcellerateXmlRouter).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_ecellerate_shipment/a.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "ascena" do
      it "sends data to Ascena PO parser" do
        klass = OpenChain::CustomHandler::Ascena::AscenaPoParser
        expect(master_setup).to receive(:custom_features_list).and_return ['Ascena PO']
        expect(klass).to receive(:delay).and_return klass
        expect(klass).to receive(:process_from_s3).with("bucket", '12345')
        cmd = {'request_type'=>'remote_file','original_path'=>'/_ascena_po/a.csv', 's3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
      it "should send data to ascena apll 856 parser if path contains _ascena_apll_asn" do
        k = OpenChain::CustomHandler::Ascena::Apll856Parser
        expect(master_setup).to receive(:custom_features_list).and_return ['Ascena APLL ASN']
        expect(k).to receive(:delay).and_return(k)
        expect(k).to receive(:process_from_s3).with("bucket", '12345')
        cmd = {'request_type'=>'remote_file','original_path'=>'/_ascena_apll_asn/a.txt','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "baillie" do
      it "should send data to the baillie order xml parser if the path contains /_po_xml and master setup includes Baillie" do
        expect(master_setup).to receive(:custom_features_list).and_return ['Baillie']
        k = OpenChain::CustomHandler::Baillie::BaillieOrderXmlParser
        expect(k).to receive(:delay).and_return(k)
        expect(k).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/baillie/_po_xml/a.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "ecellerate" do
      it "should send data to eCellerate router" do
        expect(OpenChain::CustomHandler::EcellerateXmlRouter).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_ecellerate_shipment/a.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "hm" do
      it "should send data to H&M I1 Interface if feature enabled and path contains _hm_i1" do
        expect(master_setup).to receive(:custom_features_list).and_return ['H&M I1 Interface']
        expect(OpenChain::CustomHandler::Hm::HmI1Interface).to receive(:delay).and_return OpenChain::CustomHandler::Hm::HmI1Interface
        expect(OpenChain::CustomHandler::Hm::HmI1Interface).to receive(:process_from_s3).with("bucket", '12345')
        cmd = {'request_type'=>'remote_file','original_path'=>'/_hm_i1/a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end

      it "should send data to H&M I2 Interface if feature enabled and path contains _hm_i1" do
        expect(master_setup).to receive(:custom_features_list).and_return ['H&M I2 Interface']
        expect(OpenChain::CustomHandler::Hm::HmI2ShipmentParser).to receive(:delay).with(priority: -5).and_return OpenChain::CustomHandler::Hm::HmI2ShipmentParser
        expect(OpenChain::CustomHandler::Hm::HmI2ShipmentParser).to receive(:process_from_s3).with("bucket", '12345')
        cmd = {'request_type'=>'remote_file','original_path'=>'/_hm_i2/a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "lands_end" do
      it "should send data to Lands End Parts parser" do
        u = Factory(:user,:username=>'integration')
        expect(master_setup).to receive(:custom_features_list).and_return ['Lands End Parts']
        expect(OpenChain::CustomHandler::LandsEnd::LePartsParser).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_lands_end_parts/a.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
      it "sends data to Lands End Canada Plus processor" do
        u = Factory(:user,:username=>'integration')
        expect(master_setup).to receive(:custom_features_list).and_return ['Lands End Canada Plus']
        expect(OpenChain::CustomHandler::LandsEnd::LeCanadaPlusProcessor).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_lands_end_canada_plus/a.zip','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "jjill" do
      it "should send data to J Jill 850 parser" do
        expect(master_setup).to receive(:custom_features_list).and_return ['JJill']
        expect(OpenChain::CustomHandler::JJill::JJill850XmlParser).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_jjill_850/a.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "lenox" do
      it "should send data to lenox prodct parser if feature enabled and path contains _lenox_product" do
        Factory(:user,:username=>'integration')
        expect(master_setup).to receive(:custom_features_list).and_return ['Lenox']
        expect(OpenChain::CustomHandler::Lenox::LenoxProductParser).to receive(:delay).and_return OpenChain::CustomHandler::Lenox::LenoxProductParser
        expect(OpenChain::CustomHandler::Lenox::LenoxProductParser).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_lenox_product/a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
      it "should send data to lenox po parser if feature enabled and path contains _lenox_po" do
        Factory(:user,:username=>'integration')
        expect(master_setup).to receive(:custom_features_list).and_return ['Lenox']
        expect(OpenChain::CustomHandler::Lenox::LenoxPoParser).to receive(:delay).and_return OpenChain::CustomHandler::Lenox::LenoxPoParser
        expect(OpenChain::CustomHandler::Lenox::LenoxPoParser).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_lenox_po/a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "ann_inc" do
      it "should send data to Ann Inc SAP Product Handler if feature enabled and path contains _from_sap" do
        expect(master_setup).to receive(:custom_features_list).and_return ['Ann SAP']
        expect(OpenChain::CustomHandler::AnnInc::AnnSapProductHandler).to receive(:delay).and_return OpenChain::CustomHandler::AnnInc::AnnSapProductHandler
        expect(OpenChain::CustomHandler::AnnInc::AnnSapProductHandler).to receive(:process_from_s3).with("bucket", '12345')
        cmd = {'request_type'=>'remote_file','original_path'=>'/_from_sap/a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
      it "should send data to Ack Handler if SAP enabled and path containers _from_sap and file starts with zym_ack" do
        expect(master_setup).to receive(:custom_features_list).and_return ['Ann SAP']

        p = double("parser")
        expect_any_instance_of(OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler).to receive(:delay).and_return p
        expect(p).to receive(:process_from_s3).with "bucket", '12345', {:sync_code => 'ANN-ZYM'}
        cmd = {'request_type'=>'remote_file','original_path'=>'/_from_sap/zym_ack.a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end

      it "handles ann 850 files" do
        expect(master_setup).to receive(:custom_features_list).and_return ['Ann Brokerage Feeds']

        expect(OpenChain::CustomHandler::AnnInc::AnnOrder850Parser).to receive(:delay).and_return OpenChain::CustomHandler::AnnInc::AnnOrder850Parser
        expect(OpenChain::CustomHandler::AnnInc::AnnOrder850Parser).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_ann_850/file.edi','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end

      it "handles ann invoice xml files" do
        expect(master_setup).to receive(:custom_features_list).and_return ['Ann Brokerage Feeds']

        expect(OpenChain::CustomHandler::AnnInc::AnnCommercialInvoiceXmlParser).to receive(:delay).and_return OpenChain::CustomHandler::AnnInc::AnnCommercialInvoiceXmlParser
        expect(OpenChain::CustomHandler::AnnInc::AnnCommercialInvoiceXmlParser).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_ann_invoice/file.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "eddie_bauer" do
      before :each do
        expect(master_setup).to receive(:custom_features_list).and_return ['Eddie Bauer Feeds']
      end
      it "should send ack files to ack parser for _eb_ftz_ack" do
        expect_any_instance_of(OpenChain::CustomHandler::AckFileHandler).to receive(:delay) do |instance|
          expect(instance).to receive(:process_from_s3).with "bucket", '12345', {username:'eddie_ftz_notification',sync_code: OpenChain::CustomHandler::EddieBauer::EddieBauerFtzAsnGenerator::SYNC_CODE,csv_opts:{col_sep:'|'},module_type:'Entry'}
          instance
        end
        cmd = {'request_type'=>'remote_file','original_path'=>'/_eb_ftz_ack/file.txt','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
      it "should send data to eddie bauer po parser for _eddie_po" do
        expect(OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser).to receive(:delay).and_return OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser
        expect(OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_eddie_po/file.txt','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end

      it "handles Eddie invoices" do
        expect(OpenChain::CustomHandler::EddieBauer::EddieBauerCommercialInvoiceParser).to receive(:delay).and_return OpenChain::CustomHandler::EddieBauer::EddieBauerCommercialInvoiceParser
        expect(OpenChain::CustomHandler::EddieBauer::EddieBauerCommercialInvoiceParser).to receive(:process_from_s3).with "bucket", '12345'
        cmd = {'request_type'=>'remote_file','original_path'=>'/_eddie_invoice/file.txt','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "lumber_liquidators" do
      before :each do
        expect(master_setup).to receive(:custom_features_list).and_return ["Lumber SAP"]
      end
      it "should send data to LL GTN ASN parser" do
        cmd = {'request_type'=>'remote_file','original_path'=>'/_gtn_asn_xml/x.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberGtnAsnParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with("bucket",'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq success_hash
      end
      it "should send data to LL PO parser" do
        cmd = {'request_type'=>'remote_file','original_path'=>'/_sap_po_xml/x.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with("bucket",'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq success_hash
      end
      it "should send data to LL PIR parser" do
        cmd = {'request_type'=>'remote_file','original_path'=>'/_sap_pir_xml/x.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberSapPirXmlParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with("bucket",'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq success_hash
      end

      it "should send data to LL Article parser" do
        cmd = {'request_type'=>'remote_file','original_path'=>'/_sap_article_xml/x.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberSapArticleXmlParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with("bucket",'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq success_hash
      end
      it "should send data to LL Vendor parser" do
        cmd = {'request_type'=>'remote_file','original_path'=>'/_sap_vendor_xml/x.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberSapVendorXmlParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with("bucket",'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq success_hash
      end
      it "should send data to LL shipment attachment parser" do
        cmd = {'request_type'=>'remote_file','original_path'=>'/shipment_docs/x.zip','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberShipmentAttachmentFileParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with("bucket",'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq success_hash
      end
    end
    context "msl_plus_enterprise" do
      it "should send data to MSL+ Enterprise custom handler if feature enabled and path contains _from_msl but not test and file name does not include -ack" do
        expect(master_setup).to receive(:custom_features_list).and_return ['MSL+']
        cmd = {'request_type'=>'remote_file','original_path'=>'/_from_msl/a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler).to receive(:delay).and_return OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler
        expect(OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler).to receive(:send_and_delete_ack_file_from_s3).with("bucket", '12345', 'a.csv')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
      it "should not raise errors on test files" do
        ack = double("ack_file")
        cmd = {'request_type'=>'remote_file','original_path'=>'/test_from_msl/a.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect{OpenChain::IntegrationClientCommandProcessor.process_command(cmd)}.to_not raise_error
      end
      it "should handle ack files" do
        expect(master_setup).to receive(:custom_features_list).and_return ['MSL+']

        p = double("parser")
        expect_any_instance_of(OpenChain::CustomHandler::AckFileHandler).to receive(:delay).and_return p
        expect(p).to receive(:process_from_s3).with "bucket", '12345', {:sync_code => 'MSLE',:username => ['dlombardi','mgrapp','gtung']}
        cmd = {'request_type'=>'remote_file','original_path'=>'/_from_msl/a-ack.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    context "under_armour" do
      it "sends data to UA Article Master Parser" do
        klass = OpenChain::CustomHandler::UnderArmour::UaArticleMasterParser
        expect(master_setup).to receive(:custom_features_list).and_return ['Under Armour Feeds']
        expect(klass).to receive(:delay).and_return klass
        expect(klass).to receive(:process_from_s3).with("bucket", '12345')
        cmd = {'request_type'=>'remote_file','original_path'=>'/_ua_article_master/a.xml', 's3_bucket'=>'bucket', 's3_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
      end
    end
    it 'should process CSM Acknowledgements' do
      expect(master_setup).to receive(:custom_features_list).and_return ['CSM Sync']
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::AckFileHandler).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345', {sync_code: 'csm_product', username: ['rbjork', 'aditaran']}
      cmd = {'request_type'=>'remote_file','original_path'=>'_from_csm/ACK-file.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it 'should send data to CSM Sync custom handler if feature enabled and path contains _csm_sync' do
      expect(master_setup).to receive(:custom_features_list).and_return ['CSM Sync']
      expect(OpenChain::CustomHandler::PoloCsmSyncHandler).to receive(:delay).and_return OpenChain::CustomHandler::PoloCsmSyncHandler
      expect(OpenChain::CustomHandler::PoloCsmSyncHandler).to receive(:process_from_s3).with("bucket",'12345', original_filename: 'a.xls')
      cmd = {'request_type'=>'remote_file','original_path'=>'/_csm_sync/a.xls','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it 'should send data to Kewill parser if Kewill ISF is enabled and path contains _kewill_isf' do
      expect(master_setup).to receive(:custom_features_list).and_return ['Kewill ISF']
      expect(OpenChain::CustomHandler::KewillIsfXmlParser).to receive(:delay).and_return  OpenChain::CustomHandler::KewillIsfXmlParser
      expect(OpenChain::CustomHandler::KewillIsfXmlParser).to receive(:process_from_s3).with("bucket",'12345')
      cmd = {'request_type'=>'remote_file','original_path'=>'/_kewill_isf/x.y','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it 'should send data to Fenix parser if custom feature enabled and path contains _fenix but not _fenix_invoices' do
      expect(master_setup).to receive(:custom_features_list).and_return ['fenix']
      expect(OpenChain::FenixParser).to receive(:delay).and_return OpenChain::FenixParser
      expect(OpenChain::FenixParser).to receive(:process_from_s3).with("bucket",'12345')
      cmd = {'request_type'=>'remote_file','original_path'=>'/_fenix/x.y','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it 'should send data to Fenix parser if Fenix B3 Files custom feature enabled' do
      ms = MasterSetup.new
      ms.custom_features_list = ["Fenix B3 Files"]
      allow(MasterSetup).to receive(:get).and_return ms

      expect(OpenChain::FenixParser).to receive(:delay).and_return OpenChain::FenixParser
      expect(OpenChain::FenixParser).to receive(:process_from_s3).with("bucket",'12345')
      cmd = {'request_type'=>'remote_file','original_path'=>'/_fenix/x.y','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it 'should not send data to Fenix parser if custom feature is not enabled' do
      expect(master_setup).to receive(:custom_features_list).and_return []
      cmd = {'request_type'=>'remote_file','original_path'=>'/_fenix/x.y','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq({"response_type"=>"error", "message"=>"Can't figure out what to do for path /_fenix/x.y"})
    end
    it 'should send data to Fenix invoice parser if feature enabled and path contains _fenix_invoices' do
      expect(master_setup).to receive(:custom_features_list).and_return ['fenix']
      expect(OpenChain::CustomHandler::FenixInvoiceParser).to receive(:delay).and_return OpenChain::CustomHandler::FenixInvoiceParser
      expect(OpenChain::CustomHandler::FenixInvoiceParser).to receive(:process_from_s3).with("bucket",'12345')
      expect(OpenChain::FenixParser).not_to receive(:process_from_s3).with("bucket",'12345')
      cmd = {'request_type'=>'remote_file','original_path'=>'/_fenix_invoices/x.y','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it 'should not send data to Fenix invoice parser if custom feature is not enabled' do
      expect(master_setup).to receive(:custom_features_list).and_return []
      cmd = {'request_type'=>'remote_file','original_path'=>'/_fenix_invoices/x.y','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq({"response_type"=>"error", "message"=>"Can't figure out what to do for path /_fenix_invoices/x.y"})
    end
    it 'should send data to Alliance Day End Invoice parser if custom feature enabled and path contains _alliance_day_end_invoices' do
      expect(master_setup).to receive(:custom_features_list).and_return ['alliance']
      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser).to receive(:delay).and_return OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser
      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser).to receive(:process_from_s3).with("bucket",'12345', original_filename: "x.y")
      cmd = {'request_type'=>'remote_file','original_path'=>'/_alliance_day_end_invoices/x.y','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it 'should send data to Alliance Day End Check parser if custom feature enabled and path contains _alliance_day_end_invoices' do
      expect(master_setup).to receive(:custom_features_list).and_return ['alliance']
      expect(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser).to receive(:delay).and_return OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser
      expect(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser).to receive(:process_from_s3).with("bucket",'12345', original_filename: "x.y")
      cmd = {'request_type'=>'remote_file','original_path'=>'/_alliance_day_end_checks/x.y','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it 'should create linkable attachment if linkable attachment rule match' do
      LinkableAttachmentImportRule.create!(:path=>'/path/to',:model_field_uid=>'prod_uid')
      cmd = {'request_type'=>'remote_file','original_path'=>'/path/to/this.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(LinkableAttachmentImportRule).to receive(:delay).and_return LinkableAttachmentImportRule
      expect(LinkableAttachmentImportRule).to receive(:process_from_s3).with("bucket",'12345', original_filename: 'this.csv', original_path: '/path/to')
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it "should send to VF 850 Parser" do
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::Polo::Polo850VandegriftParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_polo_850/file.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "should send efocus ack files to ack handler" do
      expect(master_setup).to receive(:custom_features_list).and_return ['e-Focus Products']
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::AckFileHandler).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345', {:sync_code => OpenChain::CustomHandler::PoloEfocusProductGenerator::SYNC_CODE, :username => ['rbjork']}
      cmd = {'request_type'=>'remote_file','original_path'=>'/_efocus_ack/file.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "should send Shoes For Crews PO files to handler" do
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoSpreadsheetHandler).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_shoes_po/file.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
    it "sends Shoes For Crews zip files to handler" do
      p = double("parser")
      expect(OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoZipHandler).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_shoes_for_crews_po_zip/file.zip','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "should send Tradecard 810 files to handler" do
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::Polo::PoloTradecard810Parser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_polo_tradecard_810/file.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "processes imported files" do
      cmd = {'request_type'=>'remote_file','original_path'=>'/test/to_chain/module/file.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(ImportedFile).to receive(:delay).and_return ImportedFile
      expect(ImportedFile).to receive(:process_integration_imported_file).with("bucket", '12345', '/test/to_chain/module/file.csv')
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it 'should return error if not imported_file or linkable_attachment' do
      expect(LinkableAttachmentImportRule).to receive(:find_import_rule).and_return(nil)
      cmd = {'request_type'=>'remote_file','original_path'=>'/some/invalid/path','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq({'response_type'=>'error','message'=>"Can't figure out what to do for path /some/invalid/path"})
    end

    it "handles Siemens .dat.pgp files" do
      p = double("OpenChain::CustomHandler::Siemens::SiemensDecryptionPassthroughHandler")
      expect_any_instance_of(OpenChain::CustomHandler::Siemens::SiemensDecryptionPassthroughHandler).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345', original_filename: 'file.dat.pgp'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_siemens_decrypt/file.dat.pgp','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it 'handles kewill export files' do
      expect(master_setup).to receive(:custom_features_list).and_return ['Kewill Exports']
      p = double("OpenChain::CustomHandler::KewillExportShipmentParser")
      expect_any_instance_of(OpenChain::CustomHandler::KewillExportShipmentParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_kewill_exports/file.dat','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles polo 850 files" do
      expect(master_setup).to receive(:custom_features_list).and_return ["RL 850"]
      expect(OpenChain::CustomHandler::Polo::Polo850Parser).to receive(:delay).and_return OpenChain::CustomHandler::Polo::Polo850Parser
      expect(OpenChain::CustomHandler::Polo::Polo850Parser).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/polo/_850/file.dat','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles ua po files" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Under Armour Feeds']
      p = class_double(OpenChain::CustomHandler::UnderArmour::UnderArmourPoXmlParser)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmourPoXmlParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_ua_po_xml/file.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles ua 856 files" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Under Armour Feeds']
      p = class_double(OpenChain::CustomHandler::UnderArmour::UnderArmour856XmlParser)
      expect(OpenChain::CustomHandler::UnderArmour::UnderArmour856XmlParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_ua_856_xml/file.xml','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles burlington 850 files" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Burlington']
      p = class_double("OpenChain::CustomHandler::Burlington::Burlington850Parser")
      expect(OpenChain::CustomHandler::Burlington::Burlington850Parser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_burlington_850/file.dat','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles burlington 856 files" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Burlington']
      p = class_double("OpenChain::CustomHandler::Burlington::Burlington856Parser")
      expect(OpenChain::CustomHandler::Burlington::Burlington856Parser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_burlington_856/file.dat','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles amersports 856 files" do
      expect(master_setup).to receive(:custom_features_list).and_return ['AmerSports']
      p = class_double("OpenChain::CustomHandler::AmerSports::AmerSports856CiLoadParser")
      expect(OpenChain::CustomHandler::AmerSports::AmerSports856CiLoadParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_amersports_856/file.dat','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles Talbots 850s" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Talbots']
      p = class_double("OpenChain::CustomHandler::Talbots::Talbots850Parser")
      expect(OpenChain::CustomHandler::Talbots::Talbots850Parser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_talbots_850/file.edi','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles Talbots 856s" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Talbots']
      p = class_double("OpenChain::CustomHandler::Talbots::Talbots856Parser")
      expect(OpenChain::CustomHandler::Talbots::Talbots856Parser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_talbots_856/file.edi','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles kewill entries" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Kewill Entries']
      p = class_double("OpenChain::CustomHandler::KewillEntryParser")
      expect(OpenChain::CustomHandler::KewillEntryParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/_kewill_entry/file.json','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles kewill statements" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Kewill Statements']
      p = class_double("OpenChain::CustomHandler::Vandegrift::KewillStatementParser")
      expect(OpenChain::CustomHandler::Vandegrift::KewillStatementParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/kewill_statements/file.json','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles ellery orders" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Ellery']
      p = class_double("OpenChain::CustomHandler::Ellery::ElleryOrderParser")
      expect(OpenChain::CustomHandler::Ellery::ElleryOrderParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/ellery_po/file.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles ellery 856s" do
      expect(master_setup).to receive(:custom_features_list).and_return ['Ellery']
      p = class_double("OpenChain::CustomHandler::Ellery::Ellery856Parser")
      expect(OpenChain::CustomHandler::Ellery::Ellery856Parser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/ellery_856/file.csv','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles legacy style sqs messages" do 
      expect(master_setup).to receive(:custom_features_list).and_return ['Ellery']
      p = class_double("OpenChain::CustomHandler::Ellery::ElleryOrderParser")
      expect(OpenChain::CustomHandler::Ellery::ElleryOrderParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/ellery_po/file.csv', 'remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end

    it "handles vandegrift customer activity reports" do
      p = class_double("OpenChain::CustomHandler::Vandegrift::VandegriftKewillCustomerActivityReportParser")
      expect(OpenChain::CustomHandler::Vandegrift::VandegriftKewillCustomerActivityReportParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with "bucket", '12345'
      cmd = {'request_type'=>'remote_file','original_path'=>'/vfi_kewill_customer_activity_report/file.rpt','s3_bucket'=>'bucket', 's3_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(success_hash)
    end
  end

  it 'should return error if bad request type' do
    cmd = {'something_bad'=>'crap'}
    expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq({'response_type'=>'error','message'=>"Unknown command: #{cmd}"})
  end

end
