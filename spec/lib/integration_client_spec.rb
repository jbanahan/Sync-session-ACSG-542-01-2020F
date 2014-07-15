require 'spec_helper'
require 'open_chain/integration_client'
require 'open_chain/s3'

describe OpenChain::IntegrationClient do
  before :each do
    @system_code = 'mytestsyscode'
    MasterSetup.get.update_attributes(:system_code=>@system_code)
    @queue = mock("SQS Queue")
    fake_queue_collection = double("queues")
    AWS::SQS.any_instance.stub(:queues).and_return fake_queue_collection
    fake_queue_collection.stub(:create).with(@system_code).and_return @queue
  end

  def mock_command body, sent_at, require_delete = true
    cmd = double("cmd_#{sent_at.to_s}")
    cmd.stub(:body).and_return body.to_json
    cmd.stub(:sent_at).and_return sent_at
    cmd.should_receive(:delete) if require_delete
    cmd
  end

  describe "process_queue" do
    it 'creates specified queue, processes messages from it and then stops' do
      c1_mock = mock_command({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}, 10.seconds.ago)
      c_shutdown_mock = mock_command({:request_type=>'shutdown'}, 3.seconds.ago)

      @queue.stub(:visible_messages).and_return 1, 1, 0
      @queue.should_receive(:receive_messages).with(visibility_timeout: 63, limit:10, attributes: [:sent_at], wait_time_seconds: 0).and_return [c1_mock]
      @queue.should_receive(:receive_messages).with(visibility_timeout: 63, limit:10, attributes: [:sent_at], wait_time_seconds: 0).and_return [c_shutdown_mock]

      
      remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
      OpenChain::IntegrationClientCommandProcessor.should_receive(:process_remote_file).and_return(remote_file_response)
      expect(OpenChain::IntegrationClient.process_queue @system_code, 3).to eq 2
    end

    it "respects the max message count" do
      # Set the visible count so it shows more messages available than we actually want to handle
      @queue.stub(:visible_messages).and_return 1, 1
      cmd = mock_command({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}, 10.seconds.ago)
      @queue.should_receive(:receive_messages).with(visibility_timeout: 61, limit:10, attributes: [:sent_at], wait_time_seconds: 0).and_return [cmd]

      remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
      OpenChain::IntegrationClientCommandProcessor.should_receive(:process_remote_file).and_return(remote_file_response)
      expect(OpenChain::IntegrationClient.process_queue @system_code, 1).to eq 1
    end

    it 'rescues errors from process command' do
      cmd = mock_command({:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}, 10.seconds.ago)
      #Just mock out the retrieve queue messages call here, since it's not needed to test message handling
      OpenChain::IntegrationClient.should_receive(:retrieve_queue_messages).with('q', 500).and_return [cmd]
      OpenChain::IntegrationClientCommandProcessor.should_receive(:process_command).with(JSON.parse(cmd.body)).and_raise "Error"
      StandardError.any_instance.should_receive(:log_me).with ["SQS Message: #{cmd.body}"]

      OpenChain::IntegrationClient.process_queue 'q'
    end

    it "errors if queue name is blank" do
      expect {OpenChain::IntegrationClient.process_queue ''}.to raise_error "Queue Name must be provided."
    end
  end

  describe "run_schedulable" do
    it "uses master setup to get queue name and defaults to 500 max messages" do
      OpenChain::IntegrationClient.should_receive(:process_queue).with @system_code, 500
      OpenChain::IntegrationClient.run_schedulable
    end

    it "uses provided parameters" do
      OpenChain::IntegrationClient.should_receive(:process_queue).with 'queue', 5
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
    context :lenox do
      it "should send data to lenox prodct parser if feature enabled and path contains _lenox_product" do
        Factory(:user,:username=>'integration')
        MasterSetup.any_instance.should_receive(:custom_feature?).with('Lenox').and_return(true)
        OpenChain::CustomHandler::Lenox::LenoxProductParser.should_receive(:delay).and_return OpenChain::CustomHandler::Lenox::LenoxProductParser
        OpenChain::CustomHandler::Lenox::LenoxProductParser.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_lenox_product/a.csv','remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
      it "should send data to lenox po parser if feature enabled and path contains _lenox_po" do
        Factory(:user,:username=>'integration')
        MasterSetup.any_instance.should_receive(:custom_feature?).with('Lenox').and_return(true)
        OpenChain::CustomHandler::Lenox::LenoxPoParser.should_receive(:delay).and_return OpenChain::CustomHandler::Lenox::LenoxPoParser
        OpenChain::CustomHandler::Lenox::LenoxPoParser.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_lenox_po/a.csv','remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
    end
    context :ann_inc do
      it "should send data to Ann Inc SAP Product Handler if feature enabled and path contains _from_sap" do
        MasterSetup.any_instance.should_receive(:custom_feature?).with('Ann SAP').and_return(true)
        OpenChain::CustomHandler::AnnInc::AnnSapProductHandler.should_receive(:delay).and_return OpenChain::CustomHandler::AnnInc::AnnSapProductHandler
        OpenChain::CustomHandler::AnnInc::AnnSapProductHandler.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name, '12345')
        cmd = {'request_type'=>'remote_file','path'=>'/_from_sap/a.csv','remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
      it "should send data to Ack Handler if SAP enabled and path containers _from_sap and file starts with zym_ack" do
        MasterSetup.any_instance.should_receive(:custom_feature?).with('Ann SAP').and_return(true)

        p = double("parser")
        OpenChain::CustomHandler::AnnInc::AnnZymAckFileHandler.any_instance.should_receive(:delay).and_return p
        p.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {:sync_code => 'ANN-ZYM'}
        cmd = {'request_type'=>'remote_file','path'=>'/_from_sap/zym_ack.a.csv','remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
    end
    context :eddie_bauer do
      it "should send ack files to ack parser for _eb_ftz_ack" do
        p = double("parser")
        OpenChain::CustomHandler::AckFileHandler.should_receive(:new).and_return p
        p.should_receive(:delay).and_return p
        p.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {username:'eddie_ftz_notification',sync_code: OpenChain::CustomHandler::EddieBauer::EddieBauerFtzAsnGenerator::SYNC_CODE,csv_opts:{col_sep:'|'},module_type:'Entry'}
        cmd = {'request_type'=>'remote_file','path'=>'/_eb_ftz_ack/','remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
      it "should send data to eddie bauer po parser for _eddie_po" do
        p = double("parser")
        OpenChain::CustomHandler::EddieBauer::EddieBauerPoParser.should_receive(:delay).and_return p
        p.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_eddie_po/','remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
    end
    context :msl_plus_enterprise do
      it "should send data to MSL+ Enterprise custom handler if feature enabled and path contains _from_msl but not test and file name does not include -ack" do
        MasterSetup.any_instance.should_receive(:custom_feature?).with('MSL+').and_return(true)
        cmd = {'request_type'=>'remote_file','path'=>'/_from_msl/a.csv','remote_path'=>'12345'}
        OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.should_receive(:delay).and_return OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler
        OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.should_receive(:send_and_delete_ack_file_from_s3).with(OpenChain::S3.integration_bucket_name, '12345', 'a.csv')
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
      it "should not raise errors on test files" do
        ack = mock("ack_file")
        cmd = {'request_type'=>'remote_file','path'=>'/test_from_msl/a.csv','remote_path'=>'12345'}
        expect{OpenChain::IntegrationClientCommandProcessor.process_command(cmd)}.to_not raise_error
      end
      it "should handle ack files" do
        MasterSetup.any_instance.should_receive(:custom_feature?).with('MSL+').and_return(true)

        p = double("parser")
        OpenChain::CustomHandler::AckFileHandler.any_instance.should_receive(:delay).and_return p
        p.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {:sync_code => 'MSLE'}
        cmd = {'request_type'=>'remote_file','path'=>'/_from_msl/a-ack.csv','remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
    end
    it 'should process CSM Acknowledgements' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('CSM Sync').and_return(true)
      p = double("parser")
      OpenChain::CustomHandler::AckFileHandler.any_instance.should_receive(:delay).and_return p
      p.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {sync_code: 'csm_product', username: ['rbjork', 'aditaran']}
      cmd = {'request_type'=>'remote_file','path'=>'_from_csm/ACK-file.csv','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
    end
    it 'should send data to CSM Sync custom handler if feature enabled and path contains _csm_sync' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('CSM Sync').and_return(true)
      OpenChain::CustomHandler::PoloCsmSyncHandler.should_receive(:delay).and_return OpenChain::CustomHandler::PoloCsmSyncHandler
      OpenChain::CustomHandler::PoloCsmSyncHandler.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345', original_filename: 'a.xls')
      cmd = {'request_type'=>'remote_file','path'=>'/_csm_sync/a.xls','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should send data to Kewill parser if Alliance is enabled and path contains _kewill_isf' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('alliance').and_return(true)
      OpenChain::CustomHandler::KewillIsfXmlParser.should_receive(:delay).and_return  OpenChain::CustomHandler::KewillIsfXmlParser
      OpenChain::CustomHandler::KewillIsfXmlParser.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_kewill_isf/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should send data to Fenix parser if custom feature enabled and path contains _fenix but not _fenix_invoices' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('fenix').and_return(true)
      OpenChain::FenixParser.should_receive(:delay).and_return OpenChain::FenixParser
      OpenChain::FenixParser.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should not send data to Fenix parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {"response_type"=>"error", "message"=>"Can't figure out what to do for path /_fenix/x.y"} 
    end
    it 'should send data to Fenix invoice parser if feature enabled and path contains _fenix_invoices' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('fenix').and_return(true)
      OpenChain::CustomHandler::FenixInvoiceParser.should_receive(:delay).and_return OpenChain::CustomHandler::FenixInvoiceParser
      OpenChain::CustomHandler::FenixInvoiceParser.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      OpenChain::FenixParser.should_not_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix_invoices/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should not send data to Fenix invoice parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix_invoices/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {"response_type"=>"error", "message"=>"Can't figure out what to do for path /_fenix_invoices/x.y"} 
    end
    it 'should send data to Alliance parser if custom feature enabled and path contains _alliance' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('alliance').and_return(true)
      OpenChain::AllianceParser.should_receive(:delay).and_return OpenChain::AllianceParser
      OpenChain::AllianceParser.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_alliance/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should not send data to alliance parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_alliance/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {"response_type"=>"error", "message"=>"Can't figure out what to do for path /_alliance/x.y"} 
    end
    it 'should create linkable attachment if linkable attachment rule match' do
      LinkableAttachmentImportRule.create!(:path=>'/path/to',:model_field_uid=>'prod_uid')
      cmd = {'request_type'=>'remote_file','path'=>'/path/to/this.csv','remote_path'=>'12345'}
      LinkableAttachmentImportRule.should_receive(:delay).and_return LinkableAttachmentImportRule
      LinkableAttachmentImportRule.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345', original_filename: 'this.csv', original_path: '/path/to')
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it "should send to VF 850 Parser" do
      p = double("parser")
      OpenChain::CustomHandler::Polo::Polo850VandegriftParser.any_instance.should_receive(:delay).and_return p
      p.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/_polo_850/file.xml','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
    end

    it "should send efocus ack files to ack handler" do 
      MasterSetup.any_instance.should_receive(:custom_feature?).with('e-Focus Products').and_return(true)
      p = double("parser")
      OpenChain::CustomHandler::AckFileHandler.any_instance.should_receive(:delay).and_return p
      p.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345', {:sync_code => OpenChain::CustomHandler::PoloEfocusProductGenerator::SYNC_CODE}
      cmd = {'request_type'=>'remote_file','path'=>'/_efocus_ack/file.csv','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
    end

    it "should send Shoes For Crews PO files to handler" do
      p = double("parser")
      OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoSpreadsheetHandler.any_instance.should_receive(:delay).and_return p
      p.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/_shoes_po/file.csv','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
    end

    it "processes imported files" do
      LinkableAttachmentImportRule.should_receive(:find_import_rule).and_return(nil)
      cmd = {'request_type'=>'remote_file','path'=>'/test/to_chain/module/file.csv','remote_path'=>'12345'}
      ImportedFile.should_receive(:delay).and_return ImportedFile
      ImportedFile.should_receive(:process_integration_imported_file).with(OpenChain::S3.integration_bucket_name, '12345', '/test/to_chain/module/file.csv')
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
    end

    it 'should return error if not imported_file or linkable_attachment' do
      LinkableAttachmentImportRule.should_receive(:find_import_rule).and_return(nil)
      cmd = {'request_type'=>'remote_file','path'=>'/some/invalid/path','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'error','message'=>"Can't figure out what to do for path #{cmd['path']}"}
    end
  end

  it 'should return error if bad request type' do
    cmd = {'something_bad'=>'crap'}
    OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'error','message'=>"Unknown command: #{cmd}"}
  end

end
