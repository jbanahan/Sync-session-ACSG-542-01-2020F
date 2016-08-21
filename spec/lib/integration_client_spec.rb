require 'spec_helper'
require 'open_chain/integration_client'
require 'open_chain/s3'

describe OpenChain::IntegrationClient do
  before :each do
    @system_code = 'mytestsyscode'
    MasterSetup.get.update_attributes(:system_code=>@system_code)
    @queue = double("SQS Queue")
    fake_queue_collection = double("queues")
    allow_any_instance_of(AWS::SQS).to receive(:queues).and_return fake_queue_collection
    allow(fake_queue_collection).to receive(:create).with(@system_code).and_return @queue
  end

  def mock_command body, sent_at, require_delete = true
    cmd = double("cmd_#{sent_at.to_s}")
    allow(cmd).to receive(:body).and_return body.to_json
    allow(cmd).to receive(:sent_at).and_return sent_at
    expect(cmd).to receive(:delete) if require_delete
    cmd
  end

  describe "process_queue" do
    it 'creates specified queue, processes messages from it and then stops' do
      c1_mock = mock_command({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}, 10.seconds.ago)
      c_shutdown_mock = mock_command({:request_type=>'shutdown'}, 3.seconds.ago)

      allow(@queue).to receive(:visible_messages).and_return 1, 1, 0
      expect(@queue).to receive(:receive_messages).with(visibility_timeout: 63, limit:10, attributes: [:sent_at], wait_time_seconds: 0).and_return [c1_mock]
      expect(@queue).to receive(:receive_messages).with(visibility_timeout: 63, limit:10, attributes: [:sent_at], wait_time_seconds: 0).and_return [c_shutdown_mock]


      remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
      expect(OpenChain::IntegrationClientCommandProcessor).to receive(:process_remote_file).and_return(remote_file_response)
      expect(OpenChain::IntegrationClient.process_queue @system_code, 3).to eq 2
    end

    it "respects the max message count" do
      # Set the visible count so it shows more messages available than we actually want to handle
      allow(@queue).to receive(:visible_messages).and_return 1, 1
      cmd = mock_command({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}, 10.seconds.ago)
      expect(@queue).to receive(:receive_messages).with(visibility_timeout: 61, limit:10, attributes: [:sent_at], wait_time_seconds: 0).and_return [cmd]

      remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
      expect(OpenChain::IntegrationClientCommandProcessor).to receive(:process_remote_file).and_return(remote_file_response)
      expect(OpenChain::IntegrationClient.process_queue @system_code, 1).to eq 1
    end

    it 'rescues errors from process command' do
      cmd = mock_command({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}, 10.seconds.ago)
      #Just mock out the retrieve queue messages call here, since it's not needed to test message handling
      expect(OpenChain::IntegrationClient).to receive(:retrieve_queue_messages).with('q', 500).and_return [cmd]
      expect(OpenChain::IntegrationClientCommandProcessor).to receive(:process_command).with(JSON.parse(cmd.body)).and_raise "Error"
      expect_any_instance_of(RuntimeError).to receive(:log_me).with ["SQS Message: #{cmd.body}"]

      OpenChain::IntegrationClient.process_queue 'q'
    end

    it "errors if queue name is blank" do
      expect {OpenChain::IntegrationClient.process_queue ''}.to raise_error "Queue Name must be provided."
    end
  end

  describe "run_schedulable" do
    it "uses master setup to get queue name and defaults to 500 max messages" do
      expect(OpenChain::IntegrationClient).to receive(:process_queue).with @system_code, 500
      OpenChain::IntegrationClient.run_schedulable
    end

    it "uses provided parameters" do
      expect(OpenChain::IntegrationClient).to receive(:process_queue).with 'queue', 5
      OpenChain::IntegrationClient.run_schedulable({'queue_name' => 'queue', 'max_message_count' => 5})
    end
  end
end

describe OpenChain::IntegrationClientCommandProcessor do

  context 'request type: remote_file' do
    before(:each) do
      @success_hash = {'response_type'=>'remote_file','status'=>'success'}
      @ws = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false
    end
    after(:each) do
      Delayed::Worker.delay_jobs = @ws
    end
    context :ecellerate do
      it "should send data to eCellerate router" do
        expect(OpenChain::CustomHandler::EcellerateXmlRouter).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_ecellerate_shipment/a.xml','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
    end
    context :hm do
      it "should send data to H&M I1 Interface if feature enabled and path contains _hm_i1" do
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('H&M I1 Interface').and_return(true)
        expect(OpenChain::CustomHandler::Hm::HmI1Interface).to receive(:delay).and_return OpenChain::CustomHandler::Hm::HmI1Interface
        expect(OpenChain::CustomHandler::Hm::HmI1Interface).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name, '12345')
        cmd = {'request_type'=>'remote_file','path'=>'/_hm_i1/a.csv','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
    end
    context :lands_end do
      it "should send data to Lands End Parts parser" do
        u = Factory(:user,:username=>'integration')
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('Lands End Parts').and_return(true)
        expect(OpenChain::CustomHandler::LandsEnd::LePartsParser).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_lands_end_parts/a.xml','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
      it "sends data to Lands End Canada Plus processor" do
        u = Factory(:user,:username=>'integration')
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('Lands End Canada Plus').and_return(true)
        expect(OpenChain::CustomHandler::LandsEnd::LeCanadaPlusProcessor).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_lands_end_canada_plus/a.zip','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
    end
    context :jjill do
      it "should send data to J Jill 850 parser" do
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('JJill').and_return(true)
        expect(OpenChain::CustomHandler::JJill::JJill850XmlParser).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_jjill_850/a.xml','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
    end
    context :lenox do
      it "should send data to lenox prodct parser if feature enabled and path contains _lenox_product" do
        Factory(:user,:username=>'integration')
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('Lenox').and_return(true)
        expect(OpenChain::CustomHandler::Lenox::LenoxProductParser).to receive(:delay).and_return OpenChain::CustomHandler::Lenox::LenoxProductParser
        expect(OpenChain::CustomHandler::Lenox::LenoxProductParser).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_lenox_product/a.csv','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
      it "should send data to lenox po parser if feature enabled and path contains _lenox_po" do
        Factory(:user,:username=>'integration')
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('Lenox').and_return(true)
        expect(OpenChain::CustomHandler::Lenox::LenoxPoParser).to receive(:delay).and_return OpenChain::CustomHandler::Lenox::LenoxPoParser
        expect(OpenChain::CustomHandler::Lenox::LenoxPoParser).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_lenox_po/a.csv','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
    end
    context :ann_inc do
      it "should send data to Ann Inc SAP Product Handler if feature enabled and path contains _from_sap" do
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('Ann SAP').and_return(true)
        expect(OpenChain::CustomHandler::AnnInc::AnnSapProductHandler).to receive(:delay).and_return OpenChain::CustomHandler::AnnInc::AnnSapProductHandler
        expect(OpenChain::CustomHandler::AnnInc::AnnSapProductHandler).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name, '12345')
        cmd = {'request_type'=>'remote_file','path'=>'/_from_sap/a.csv','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
      it "should send data to Ack Handler if SAP enabled and path containers _from_sap and file starts with zym_ack" do
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('Ann SAP').and_return(true)

        p = double("parser")
        expect_any_instance_of(OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler).to receive(:delay).and_return p
        expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {:sync_code => 'ANN-ZYM'}
        cmd = {'request_type'=>'remote_file','path'=>'/_from_sap/zym_ack.a.csv','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
    end
    context :eddie_bauer do
      it "should send ack files to ack parser for _eb_ftz_ack" do
        p = double("parser")
        expect(OpenChain::CustomHandler::AckFileHandler).to receive(:new).and_return p
        expect(p).to receive(:delay).and_return p
        expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {username:'eddie_ftz_notification',sync_code: OpenChain::CustomHandler::EddieBauer::EddieBauerFtzAsnGenerator::SYNC_CODE,csv_opts:{col_sep:'|'},module_type:'Entry'}
        cmd = {'request_type'=>'remote_file','path'=>'/_eb_ftz_ack/','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
      it "should send data to eddie bauer po parser for _eddie_po" do
        p = double("parser")
        expect(OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser).to receive(:delay).and_return p
        expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_eddie_po/','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
    end
    context :lumber_liquidators do
      before :each do
        MasterSetup.get.update_attributes(custom_features:'Lumber SAP')
      end
      it "should send data to LL PO parser" do
        cmd = {'request_type'=>'remote_file','path'=>'/_sap_po_xml/x.xml','remote_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq @success_hash
      end
      it "should send data to LL PIR parser" do
        cmd = {'request_type'=>'remote_file','path'=>'/_sap_pir_xml/x.xml','remote_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberSapPirXmlParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq @success_hash
      end

      it "should send data to LL Article parser" do
        cmd = {'request_type'=>'remote_file','path'=>'/_sap_article_xml/x.xml','remote_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberSapArticleXmlParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq @success_hash
      end
      it "should send data to LL Vendor parser" do
        cmd = {'request_type'=>'remote_file','path'=>'/_sap_vendor_xml/x.xml','remote_path'=>'12345'}
        k = OpenChain::CustomHandler::LumberLiquidators::LumberSapVendorXmlParser
        expect(k).to receive(:delay).and_return k
        expect(k).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq @success_hash
      end
    end
    context :msl_plus_enterprise do
      it "should send data to MSL+ Enterprise custom handler if feature enabled and path contains _from_msl but not test and file name does not include -ack" do
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('MSL+').and_return(true)
        cmd = {'request_type'=>'remote_file','path'=>'/_from_msl/a.csv','remote_path'=>'12345'}
        expect(OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler).to receive(:delay).and_return OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler
        expect(OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler).to receive(:send_and_delete_ack_file_from_s3).with(OpenChain::S3.integration_bucket_name, '12345', 'a.csv')
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
      it "should not raise errors on test files" do
        ack = double("ack_file")
        cmd = {'request_type'=>'remote_file','path'=>'/test_from_msl/a.csv','remote_path'=>'12345'}
        expect{OpenChain::IntegrationClientCommandProcessor.process_command(cmd)}.to_not raise_error
      end
      it "should handle ack files" do
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('MSL+').and_return(true)

        p = double("parser")
        expect_any_instance_of(OpenChain::CustomHandler::AckFileHandler).to receive(:delay).and_return p
        expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {:sync_code => 'MSLE',:username => ['dlombardi','mgrapp','gtung']}
        cmd = {'request_type'=>'remote_file','path'=>'/_from_msl/a-ack.csv','remote_path'=>'12345'}
        expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
      end
    end
    it 'should process CSM Acknowledgements' do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('CSM Sync').and_return(true)
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::AckFileHandler).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {sync_code: 'csm_product', username: ['rbjork', 'aditaran']}
      cmd = {'request_type'=>'remote_file','path'=>'_from_csm/ACK-file.csv','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it 'should send data to CSM Sync custom handler if feature enabled and path contains _csm_sync' do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('CSM Sync').and_return(true)
      expect(OpenChain::CustomHandler::PoloCsmSyncHandler).to receive(:delay).and_return OpenChain::CustomHandler::PoloCsmSyncHandler
      expect(OpenChain::CustomHandler::PoloCsmSyncHandler).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345', original_filename: 'a.xls')
      cmd = {'request_type'=>'remote_file','path'=>'/_csm_sync/a.xls','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it 'should send data to Kewill parser if Alliance is enabled and path contains _kewill_isf' do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('alliance').and_return(true)
      expect(OpenChain::CustomHandler::KewillIsfXmlParser).to receive(:delay).and_return  OpenChain::CustomHandler::KewillIsfXmlParser
      expect(OpenChain::CustomHandler::KewillIsfXmlParser).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_kewill_isf/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it 'should send data to Fenix parser if custom feature enabled and path contains _fenix but not _fenix_invoices' do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('fenix').and_return(true)
      expect(OpenChain::FenixParser).to receive(:delay).and_return OpenChain::FenixParser
      expect(OpenChain::FenixParser).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it 'should send data to Fenix parser if Fenix B3 Files custom feature enabled' do
      ms = MasterSetup.new
      ms.custom_features_list = ["Fenix B3 Files"]
      allow(MasterSetup).to receive(:get).and_return ms

      expect(OpenChain::FenixParser).to receive(:delay).and_return OpenChain::FenixParser
      expect(OpenChain::FenixParser).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it 'should not send data to Fenix parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq({"response_type"=>"error", "message"=>"Can't figure out what to do for path /_fenix/x.y"})
    end
    it 'should send data to Fenix invoice parser if feature enabled and path contains _fenix_invoices' do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('fenix').and_return(true)
      expect(OpenChain::CustomHandler::FenixInvoiceParser).to receive(:delay).and_return OpenChain::CustomHandler::FenixInvoiceParser
      expect(OpenChain::CustomHandler::FenixInvoiceParser).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      expect(OpenChain::FenixParser).not_to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix_invoices/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it 'should not send data to Fenix invoice parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix_invoices/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq({"response_type"=>"error", "message"=>"Can't figure out what to do for path /_fenix_invoices/x.y"})
    end
    it 'should send data to Alliance parser if custom feature enabled and path contains _alliance' do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('alliance').and_return(true)
      # This path is a no-op now.
      expect(OpenChain::AllianceParser).not_to receive(:delay)
      cmd = {'request_type'=>'remote_file','path'=>'/_alliance/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it 'should not send data to alliance parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_alliance/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq({"response_type"=>"error", "message"=>"Can't figure out what to do for path /_alliance/x.y"})
    end
    it 'should send data to Alliance Day End Invoice parser if custom feature enabled and path contains _alliance_day_end_invoices' do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('alliance').and_return(true)
      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser).to receive(:delay).and_return OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser
      expect(OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345', original_filename: "x.y")
      cmd = {'request_type'=>'remote_file','path'=>'/_alliance_day_end_invoices/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it 'should send data to Alliance Day End Check parser if custom feature enabled and path contains _alliance_day_end_invoices' do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('alliance').and_return(true)
      expect(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser).to receive(:delay).and_return OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser
      expect(OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345', original_filename: "x.y")
      cmd = {'request_type'=>'remote_file','path'=>'/_alliance_day_end_checks/x.y','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it 'should create linkable attachment if linkable attachment rule match' do
      LinkableAttachmentImportRule.create!(:path=>'/path/to',:model_field_uid=>'prod_uid')
      cmd = {'request_type'=>'remote_file','path'=>'/path/to/this.csv','remote_path'=>'12345'}
      expect(LinkableAttachmentImportRule).to receive(:delay).and_return LinkableAttachmentImportRule
      expect(LinkableAttachmentImportRule).to receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345', original_filename: 'this.csv', original_path: '/path/to')
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
    it "should send to VF 850 Parser" do
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::Polo::Polo850VandegriftParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/_polo_850/file.xml','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end

    it "should send efocus ack files to ack handler" do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('e-Focus Products').and_return(true)
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::AckFileHandler).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {:sync_code => OpenChain::CustomHandler::PoloEfocusProductGenerator::SYNC_CODE, :username => ['rbjork']}
      cmd = {'request_type'=>'remote_file','path'=>'/_efocus_ack/file.csv','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end

    it "should send Shoes For Crews PO files to handler" do
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoSpreadsheetHandler).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/_shoes_po/file.csv','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end

    it "should send Tradecard 810 files to handler" do
      p = double("parser")
      expect_any_instance_of(OpenChain::CustomHandler::Polo::PoloTradecard810Parser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/_polo_tradecard_810/file.csv','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end

    it "processes imported files" do
      expect(LinkableAttachmentImportRule).to receive(:find_import_rule).and_return(nil)
      cmd = {'request_type'=>'remote_file','path'=>'/test/to_chain/module/file.csv','remote_path'=>'12345'}
      expect(ImportedFile).to receive(:delay).and_return ImportedFile
      expect(ImportedFile).to receive(:process_integration_imported_file).with(OpenChain::S3.integration_bucket_name, '12345', '/test/to_chain/module/file.csv')
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end

    it 'should return error if not imported_file or linkable_attachment' do
      expect(LinkableAttachmentImportRule).to receive(:find_import_rule).and_return(nil)
      cmd = {'request_type'=>'remote_file','path'=>'/some/invalid/path','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq({'response_type'=>'error','message'=>"Can't figure out what to do for path #{cmd['path']}"})
    end

    it "handles Siemens .dat.pgp files" do
      p = double("OpenChain::CustomHandler::Siemens::SiemensDecryptionPassthroughHandler")
      expect_any_instance_of(OpenChain::CustomHandler::Siemens::SiemensDecryptionPassthroughHandler).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', original_filename: 'file.dat.pgp'
      cmd = {'request_type'=>'remote_file','path'=>'/_siemens_decrypt/file.dat.pgp','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end

    it 'handles kewill export files' do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('alliance').and_return(true)
      p = double("OpenChain::CustomHandler::KewillExportShipmentParser")
      expect_any_instance_of(OpenChain::CustomHandler::KewillExportShipmentParser).to receive(:delay).and_return p
      expect(p).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/_kewill_exports/file.dat','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end

    it "handles polo 850 files" do
      ms = double("MasterSetup")
      allow(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("RL 850").and_return true
      expect(OpenChain::CustomHandler::Polo::Polo850Parser).to receive(:delay).and_return OpenChain::CustomHandler::Polo::Polo850Parser
      expect(OpenChain::CustomHandler::Polo::Polo850Parser).to receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/polo/_850/file.dat','remote_path'=>'12345'}
      expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq(@success_hash)
    end
  end

  it 'should return error if bad request type' do
    cmd = {'something_bad'=>'crap'}
    expect(OpenChain::IntegrationClientCommandProcessor.process_command(cmd)).to eq({'response_type'=>'error','message'=>"Unknown command: #{cmd}"})
  end

end
