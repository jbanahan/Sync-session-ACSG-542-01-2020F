require 'spec_helper'
require 'open_chain/integration_client'
require 'open_chain/s3'
require 'ffi-rzmq'

describe OpenChain::IntegrationClient do
  before :each do
    system_code = 'mytestsyscode'
    MasterSetup.get.update_attributes(:system_code=>system_code)
    sqs = AWS::SQS.new AWS_CREDENTIALS
    @queue = sqs.queues.create system_code
    while @queue.visible_messages > 0
      puts 'draining test queue\n'
      @queue.receive_message {|m| m.delete}
    end
  end
  it 'should connect, start processing commands, and shutdown' do
    #
    # This will occasionlly fail when SQS returns the messages out of order, not sure how to accomodate
    #
    ScheduleServer.stub(:active_schedule_server?).and_return(:true)
    cmd_one = {:request_type=>'remote_file',:path=>'/a/b/c.txt',:remote_path=>'some/thing/remote'}
    cmd_shutdown = {:request_type=>'shutdown'}
    remote_file_response = {'response_type'=>'remote_file','status'=>'ok'}
    OpenChain::IntegrationClientCommandProcessor.should_receive(:process_remote_file).and_return(remote_file_response)
    @queue.send_message cmd_one.to_json
    sleep 3 #sleep to let queue catch up
    @queue.send_message cmd_shutdown.to_json
    OpenChain::IntegrationClient.go MasterSetup.get.system_code
  end
  it 'should not processes if not the schedule server' do
    AWS::SQS::Queue.any_instance.should_not_receive(:visible_messages)
    ScheduleServer.should_receive(:active_schedule_server?).and_return(false)
    OpenChain::IntegrationClient.go MasterSetup.get.system_code, true
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
