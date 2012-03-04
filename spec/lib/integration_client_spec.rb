require 'spec_helper'
require 'open_chain/integration_client'
require 'open_chain/s3'
require 'ffi-rzmq'

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
      OpenChain::S3.should_receive(:download_to_tempfile).with(OpenChain::S3.integration_bucket_name,'12345').and_return(@t)
    end
    it 'should send data to Fenix parser if custom feature enabled and path contains _fenix' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('fenix').and_return(true)
      OpenChain::FenixParser.should_receive(:parse).with('abcdefg')
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should not send data to Fenix parser if custom feature is not enabled' do
      cmd = {'request_type'=>'remote_file','path'=>'/_fenix/x.y','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {"response_type"=>"error", "message"=>"Can't figure out what to do for path /_fenix/x.y"} 
    end
    it 'should send data to Alliance parser if custom feature enabled and path contains _alliance' do
      MasterSetup.any_instance.should_receive(:custom_feature?).with('alliance').and_return(true)
      OpenChain::AllianceParser.should_receive(:parse).with('abcdefg')
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
      LinkableAttachmentImportRule.should_receive(:import).with(@t,'this.csv','/path/to').and_return(failed_attachment)
      cmd = {'request_type'=>'remote_file','path'=>'/path/to/this.csv','remote_path'=>'12345'}
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
        OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash
        imp = ImportedFile.where(:user_id=>@user.id,:search_setup_id=>@search_setup.id).first
        imp.module_type.should == @search_setup.module_type
        imp.attached_file_name.should == 'myfile.csv'
      end
      context 'errors' do
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
      LinkableAttachmentImportRule.should_receive(:import).and_return(nil)
      cmd = {'request_type'=>'remote_file','path'=>'/some/invalid/path','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'error','message'=>"Can't figure out what to do for path #{cmd['path']}"}
    end
  end

  it 'should return error if bad request type' do
    cmd = {'something_bad'=>'crap'}
    OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'error','message'=>"Unknown command: #{cmd}"}
  end

end
