require 'spec_helper'
require 'open_chain/integration_client'
require 'open_chain/s3'

describe OpenChain::IntegrationClient do
  before :each do
    @system_code = 'mytestsyscode'
    MasterSetup.get.update_attributes(:system_code=>@system_code)
    @queue = mock("SQS Queue")
  end
  it 'should connect, start processing commands, and shutdown' do
    AWS::SQS::QueueCollection.any_instance.should_receive(:create).with(@system_code).and_return(@queue)
    ScheduleServer.stub(:active_schedule_server?).and_return(:true)
    cmd_one = {:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}
    c1_mock = mock("cmd_one")
    c1_mock.should_receive(:body).and_return(cmd_one.to_json)
    c1_mock.should_receive(:sent_timestamp).and_return(10.seconds.ago)
    cmd_shutdown = {:request_type=>'shutdown'}
    c_shutdown_mock = mock("cmd_shutdown")
    c_shutdown_mock.should_receive(:body).and_return(cmd_shutdown.to_json)
    c_shutdown_mock.should_receive(:sent_timestamp).and_return(3.seconds.ago)
    [c1_mock,c_shutdown_mock].each do |c|
      c.should_receive(:visibility_timeout=).with(300)
      c.should_receive(:delete)
    end
    OpenChain::IntegrationClient.should_receive(:messages).with(@queue).and_yield(c1_mock).and_yield(c_shutdown_mock)
    remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
    OpenChain::IntegrationClientCommandProcessor.should_receive(:process_remote_file).and_return(remote_file_response)
    OpenChain::IntegrationClient.go MasterSetup.get.system_code, false, 0
  end
  it 'should process messages' do
    @queue.should_receive(:visible_messages).and_return(2,1,0)
    @queue.should_receive(:receive_message).exactly(2).times
    OpenChain::IntegrationClient.messages(@queue)
  end
  it 'should not processes if not the schedule server' do
    AWS::SQS::QueueCollection.any_instance.should_receive(:create).with(@system_code).and_return(@queue)
    AWS::SQS::Queue.any_instance.should_not_receive(:visible_messages)
    ScheduleServer.should_receive(:active_schedule_server?).and_return(false)
    OpenChain::IntegrationClient.go MasterSetup.get.system_code, true, 0
  end
end

describe OpenChain::IntegrationClientCommandProcessor do

  context 'request type: remote_file' do
    before(:each) do
      @t = Tempfile.new('t')
      @t.write 'abcdefg'
      @t.flush
      @success_hash = {'response_type'=>'remote_file','status'=>'success'}
      @ws = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_yield @t
    end
    after(:each) do
      Delayed::Worker.delay_jobs = @ws
      @t.close!
    end
    context :jjill do
      it "should send data to J Jill 850 parser" do
        u = Factory(:user,:username=>'integration')
        MasterSetup.any_instance.should_receive(:custom_feature?).with('JJill').and_return(true)
        OpenChain::CustomHandler::JJill::JJill850XmlParser.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
        cmd = {'request_type'=>'remote_file','path'=>'/_jjill_850/a.xml','remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
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
        Factory(:user,:username=>'integration')
        MasterSetup.any_instance.should_receive(:custom_feature?).with('Ann SAP').and_return(true)
        OpenChain::CustomHandler::AnnInc::AnnSapProductHandler.any_instance.should_receive(:process).with('abcdefg',instance_of(User))
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
        ack = mock("ack_file")
        MasterSetup.any_instance.should_receive(:custom_feature?).with('MSL+').and_return(true)
        cmd = {'request_type'=>'remote_file','path'=>'/_from_msl/a.csv','remote_path'=>'12345'}
        OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.any_instance.should_receive(:process).with('abcdefg').and_return(ack)
        OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.any_instance.should_receive(:send_and_delete_ack_file).with(ack,'a.csv')
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
      mu = Factory(:master_user,:username=>"rbjork")
      MasterSetup.any_instance.should_receive(:custom_feature?).with('CSM Sync').and_return(true)
      CustomFile.any_instance.should_receive(:attached=).with(@t).and_return(@t)
      OpenChain::CustomHandler::PoloCsmSyncHandler.any_instance.should_receive(:process)
      cmd = {'request_type'=>'remote_file','path'=>'/_csm_sync/a.xls','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
      f = CustomFile.first
      f.uploaded_by.should == User.find_by_username('rbjork')
      f.file_type.should == CustomFeaturesController::CSM_SYNC
    end
    it 'should send data to Kewill parser if Alliance is enabled and path contains _kewill_isf' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('alliance').and_return(true)
      OpenChain::CustomHandler::KewillIsfXmlParser.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_kewill_isf/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should send data to Fenix parser if custom feature enabled and path contains _fenix but not _fenix_invoices' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('fenix').and_return(true)
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
      OpenChain::CustomHandler::FenixInvoiceParser.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      OpenChain::FenixParser.should_not_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix_invoices/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should not send data to Fenix invoice parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix_invoices/x.y','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {"response_type"=>"error", "message"=>"Can't figure out what to do for path /_fenix_invoices/x.y"} 
    end
    it 'should send data to Alliance parser if custom feature enabled and path contains _alliance' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('alliance').and_return(true)
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
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
      attachment = LinkableAttachment.last
      attachment.attachment.attached_file_name.should == 'this.csv'
    end
    it 'should return error if linkable attachment cannot be created' do
      failed_attachment = LinkableAttachment.new
      failed_attachment.errors[:base] = 'errmsg'
      LinkableAttachmentImportRule.should_receive(:find_import_rule).and_return double("rule")
      LinkableAttachmentImportRule.should_receive(:import).with(@t,'this.csv','/path/to').and_return(failed_attachment)
      cmd = {'request_type'=>'remote_file','path'=>'/path/to/this.csv','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'error','message'=>'errmsg'}
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

    it "should send Tradecard 810 files to handler" do
      p = double("parser")
      OpenChain::CustomHandler::Polo::PoloTradecard810Parser.any_instance.should_receive(:delay).and_return p
      p.should_receive(:process_from_s3).with OpenChain::S3.integration_bucket_name, '12345'
      cmd = {'request_type'=>'remote_file','path'=>'/_polo_tradecard_810/file.csv','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
    end

    context 'imported_file' do
      before(:each) do
        @search_setup = Factory(:search_setup)
        @user = @search_setup.user
        @path = "/#{@user.username}/to_chain/#{@search_setup.module_type.downcase}/#{@search_setup.name}/myfile.csv"
      end
      it 'should create if path contains to_chain' do
        LinkableAttachmentImportRule.should_receive(:find_import_rule).and_return(nil)
        ImportedFile.any_instance.should_receive(:process).with(@user,{:defer=>true}).and_return(nil)
        cmd = {'request_type'=>'remote_file','path'=>@path,'remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
        imp = ImportedFile.where(:user_id=>@user.id,:search_setup_id=>@search_setup.id).first
        imp.module_type.should == @search_setup.module_type
        imp.attached_file_name.should == 'myfile.csv'
      end
      context 'errors' do

        before :each do
          Rails.stub(:env).and_return ActiveSupport::StringInquirer.new("production")
          LinkableAttachmentImportRule.should_receive(:find_import_rule).exactly(3).times.and_return(nil,nil,nil)
        end

        it 'should fail on bad user' do
          cmd = {'request_type'=>'remote_file','path'=>'/baduser/to_chain/product/search/file.csv','remote_path'=>'12345'}
          lambda { OpenChain::IntegrationClientCommandProcessor.process_command(cmd) }.should raise_error RuntimeError, 'Username baduser not found.'
        end
        it 'should fail on bad search setup name' do
          cmd = {'request_type'=>'remote_file','path'=>"/#{@user.username}/to_chain/product/badsearch/file.csv",'remote_path'=>'12345'}
          lambda { OpenChain::IntegrationClientCommandProcessor.process_command(cmd) }.should raise_error RuntimeError, 'Search named badsearch not found for module product.'
        end
        it 'should fail on locked user' do
          @user.disabled = true
          @user.save!
          cmd = {'request_type'=>'remote_file','path'=>@path,'remote_path'=>'12345'}
          lambda { OpenChain::IntegrationClientCommandProcessor.process_command(cmd) }.should raise_error RuntimeError, "User #{@user.username} is locked."
        end
      end
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
