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
    end
    after(:each) do
      Delayed::Worker.delay_jobs = @ws
      @t.close!
    end
    context :msl_plus_enterprise do
      it "should send data to MSL+ Enterprise custom handler if feature enabled and path contains _from_msl but not test and file name does not include -ack" do
        ack = mock("ack_file")
        MasterSetup.any_instance.should_receive(:custom_feature?).with('MSL+').and_return(true)
        OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
        cmd = {'request_type'=>'remote_file','path'=>'/_from_msl/a.csv','remote_path'=>'12345'}
        OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.any_instance.should_receive(:process).with('abcdefg').and_return(ack)
        OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.any_instance.should_receive(:send_and_delete_ack_file).with(ack,'a.csv')
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
      it "should handle ack files" do
        MasterSetup.any_instance.should_receive(:custom_feature?).with('MSL+').and_return(true)
        OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
        OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler.any_instance.should_receive(:process_ack_from_msl).with('abcdefg','a-ack.csv')
        cmd = {'request_type'=>'remote_file','path'=>'/_from_msl/a-ack.csv','remote_path'=>'12345'}
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
      end
    end
    it 'should send data to CSM Sync custom handler if feature enabled and path contains _csm_sync' do
      mu = Factory(:master_user,:username=>"rbjork")
      MasterSetup.any_instance.should_receive(:custom_feature?).with('CSM Sync').and_return(true)
      CustomFile.any_instance.should_receive(:attached=).with(@t).and_return(@t)
      OpenChain::CustomHandler::PoloCsmSyncHandler.any_instance.should_receive(:process)
      cmd = {'request_type'=>'remote_file','path'=>'/_csm_sync/a.xls','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
      f = CustomFile.first
      f.uploaded_by.should == User.find_by_username('rbjork')
      f.file_type.should == CustomFeaturesController::CSM_SYNC
    end
    it 'should send data to Kewill parser if Alliance is enabled and path contains _kewill_isf' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('alliance').and_return(true)
      OpenChain::CustomHandler::KewillIsfXmlParser.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_kewill_isf/x.y','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should send data to Fenix parser if custom feature enabled and path contains _fenix but not _fenix_invoices' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('fenix').and_return(true)
      OpenChain::FenixParser.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix/x.y','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should not send data to Fenix parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix/x.y','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {"response_type"=>"error", "message"=>"Can't figure out what to do for path /_fenix/x.y"} 
    end
    it 'should send data to Fenix invoice parser if feature enabled and path contains _fenix_invoices' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('fenix').and_return(true)
      OpenChain::CustomHandler::FenixInvoiceParser.should_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      OpenChain::FenixParser.should_not_receive(:process_from_s3).with(OpenChain::S3.integration_bucket_name,'12345')
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix_invoices/x.y','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
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
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should not send data to alliance parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_alliance/x.y','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {"response_type"=>"error", "message"=>"Can't figure out what to do for path /_alliance/x.y"} 
    end
    it 'should create linkable attachment if linkable attachment rule match' do
      LinkableAttachmentImportRule.create!(:path=>'/path/to',:model_field_uid=>'prod_uid')
      cmd = {'request_type'=>'remote_file','path'=>'/path/to/this.csv','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
      attachment = LinkableAttachment.last
      attachment.attachment.attached_file_name.should == 'this.csv'
    end
    it 'should return error if linkable attachment cannot be created' do
      failed_attachment = LinkableAttachment.new
      failed_attachment.errors[:base] = 'errmsg'
      LinkableAttachmentImportRule.should_receive(:import).with(@t,'this.csv','/path/to').and_return(failed_attachment)
      cmd = {'request_type'=>'remote_file','path'=>'/path/to/this.csv','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'error','message'=>'errmsg'}
    end
    context 'imported_file' do
      before(:each) do
        @search_setup = Factory(:search_setup)
        @user = @search_setup.user
        @path = "/#{@user.username}/to_chain/#{@search_setup.module_type.downcase}/#{@search_setup.name}/myfile.csv"
        LinkableAttachmentImportRule.should_receive(:import).and_return(nil)
      end
      it 'should create if path contains to_chain' do
        ImportedFile.any_instance.should_receive(:process).with(@user,{:defer=>true}).and_return(nil)
        cmd = {'request_type'=>'remote_file','path'=>@path,'remote_path'=>'12345'}
        OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
        imp = ImportedFile.where(:user_id=>@user.id,:search_setup_id=>@search_setup.id).first
        imp.module_type.should == @search_setup.module_type
        imp.attached_file_name.should == 'myfile.csv'
      end
      context 'errors' do
        it 'should fail on bad user' do
          cmd = {'request_type'=>'remote_file','path'=>'/baduser/to_chain/product/search/file.csv','remote_path'=>'12345'}
          OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
          lambda { OpenChain::IntegrationClientCommandProcessor.process_command(cmd) }.should raise_error RuntimeError, 'Username baduser not found.'
        end
        it 'should fail on bad search setup name' do
          cmd = {'request_type'=>'remote_file','path'=>"/#{@user.username}/to_chain/product/badsearch/file.csv",'remote_path'=>'12345'}
          OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
          lambda { OpenChain::IntegrationClientCommandProcessor.process_command(cmd) }.should raise_error RuntimeError, 'Search named badsearch not found for module product.'
        end
        it 'should fail on locked user' do
          @user.disabled = true
          @user.save!
          cmd = {'request_type'=>'remote_file','path'=>@path,'remote_path'=>'12345'}
          OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
          lambda { OpenChain::IntegrationClientCommandProcessor.process_command(cmd) }.should raise_error RuntimeError, "User #{@user.username} is locked."
        end
      end
    end
    it 'should return error if not imported_file or linkable_attachment' do
      LinkableAttachmentImportRule.should_receive(:import).and_return(nil)
      cmd = {'request_type'=>'remote_file','path'=>'/some/invalid/path','remote_path'=>'12345'}
      OpenChain::S3.stub(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'error','message'=>"Can't figure out what to do for path #{cmd['path']}"}
    end
  end

  it 'should return error if bad request type' do
    cmd = {'something_bad'=>'crap'}
    OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'error','message'=>"Unknown command: #{cmd}"}
  end

end
