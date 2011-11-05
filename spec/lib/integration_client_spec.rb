require 'spec_helper'
require 'open_chain/integration_client'
require 'open_chain/s3'
require 'ffi-rzmq'

describe OpenChain::IntegrationClient do
  it 'should connect, start processing commands, and shutdown' do
    registration_uri = 'tcp://localhost:9999'
    sys_code = 'mysyscode'
    zicc = mock "ZMQ Client"
    zicc.should_receive(:get_responder_port).with(registration_uri,sys_code).and_return(10101)
    zicc.should_receive(:connect_to_responder).with('tcp://localhost:10101')
    zicc.should_receive(:next_command).twice.and_return(true,false)
    OpenChain::ZmqIntegrationClientConnection.should_receive(:new).and_return(zicc)
    OpenChain::IntegrationClient.go 'localhost', 9999, sys_code
  end
end

describe OpenChain::IntegrationClientCommandProcessor do

  context 'request type: remote_file' do
    before(:each) do
      @t = Tempfile.new('t')
      @success_hash = {'response_type'=>'remote_file','status'=>'success'}
      OpenChain::S3.should_receive(:download_to_tempfile).with(OpenChain::S3.bucket_name,'12345').and_return(@t)
    end
    it 'should create linkable attachment if linkable attachment rule match' do
      LinkableAttachmentImportRule.should_receive(:import).with(@t.path,'this.csv','/path/to').and_return(LinkableAttachment.new)
      cmd = {'request_type'=>'remote_file','path'=>'/path/to/this.csv','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == @success_hash 
    end
    it 'should return error if linkable attachment cannot be created' do
      failed_attachment = LinkableAttachment.new
      failed_attachment.errors[:base] = 'errmsg'
      LinkableAttachmentImportRule.should_receive(:import).with(@t.path,'this.csv','/path/to').and_return(failed_attachment)
      cmd = {'request_type'=>'remote_file','path'=>'/path/to/this.csv','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'remote_file','status'=>'errmsg'}
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
          OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'remote_file','status'=>'Username baduser not found.'}
        end
        it 'should fail on bad search setup name' do
          cmd = {'request_type'=>'remote_file','path'=>"/#{@user.username}/to_chain/product/badsearch/file.csv",'remote_path'=>'12345'}
          OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'remote_file','status'=>'Search named badsearch not found for module product.'}
        end
        it 'should fail on locked user' do
          @user.disabled = true
          @user.save!
          cmd = {'request_type'=>'remote_file','path'=>@path,'remote_path'=>'12345'}
          OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'remote_file','status'=>"User #{@user.username} is locked."}
        end
      end
    end
    it 'should return error if not imported_file or linkable_attachment' do
      LinkableAttachmentImportRule.should_receive(:import).and_return(nil)
      cmd = {'request_type'=>'remote_file','path'=>'/some/invalid/path','remote_path'=>'12345'}
      OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'remote_file','status'=>"Can't figure out what to do for path #{cmd['path']}"}
    end
  end

  it 'should return error if bad request type' do
    cmd = {'something_bad'=>'crap'}
    OpenChain::IntegrationClientCommandProcessor.process_command(cmd).should == {'response_type'=>'error','message'=>"Unknown command: #{cmd}"}
  end

end

describe OpenChain::ZmqIntegrationClientConnection do

  before(:each) do
    @sys_code = '123'
    @conn = OpenChain::ZmqIntegrationClientConnection.new
  end

  describe 'get_responder_port' do
    it 'should get responder port' do
      socket = mock "Socket"
      socket.should_receive(:connect).with("tcp://localhost:9999").and_return(nil)
      socket.should_receive(:send_string).with({:request_type=>'register',:instance_name=>@sys_code}.to_json)
      socket.should_receive(:recv_string).and_return({:response_type=>'register',:bound_port=>55555}.to_json)
      socket.should_receive(:close).and_return(nil)
      ctx = mock "Context"
      ctx.should_receive(:socket).with(ZMQ::REQ).and_return(socket)
      ZMQ::Context.should_receive(:new).and_return(ctx)
      @conn.get_responder_port("tcp://localhost:9999",@sys_code).should == 55555
    end
    it 'should raise exception on bad response' do
      socket = mock "Socket"
      socket.should_receive(:connect).with("tcp://localhost:9999").and_return(nil)
      socket.should_receive(:send_string).with({:request_type=>'register',:instance_name=>@sys_code}.to_json)
      socket.should_receive(:recv_string).and_return({:response_type=>'error',:message=>'abc'}.to_json)
      socket.should_receive(:close).and_return(nil)
      ctx = mock "Context"
      ctx.should_receive(:socket).with(ZMQ::REQ).and_return(socket)
      ZMQ::Context.should_receive(:new).and_return(ctx)
      lambda {@conn.get_responder_port("tcp://localhost:9999",@sys_code)}.should raise_error /Error registering with integration server:.*/
    end
  end

  describe 'responder' do
    it 'should connect to the responder port' do
      socket = mock "Socket"
      socket.should_receive(:connect).with("tcp://localhost:12345").and_return(nil)
      ctx = mock "Context"
      ctx.should_receive(:socket).with(ZMQ::REP).and_return(socket)
      ZMQ::Context.should_receive(:new).and_return(ctx)
      @conn.connect_to_responder("tcp://localhost:12345")
      @conn.responder_socket.should be socket
    end
    context 'close' do
      it 'should close @responder_socket if it exists' do
        socket = mock "Socket"
        socket.should_receive(:connect).with("tcp://localhost:12345").and_return(nil)
        socket.should_receive(:close).and_return(nil)
        ctx = mock "Context"
        ctx.should_receive(:socket).with(ZMQ::REP).and_return(socket)
        ZMQ::Context.should_receive(:new).and_return(ctx)
        @conn.connect_to_responder("tcp://localhost:12345")
        @conn.close
      end
      it 'should not do anything if socket is nil' do
        @conn.close #don't blow up
      end
    end
    context 'next_command' do
      it 'should raise error if not connected and socket is nil' do
        lambda {@conn.next_command}.should raise_error 'Cannot get next Integration Server command: Socket not set.'
      end
      it 'should get next command if connected and socket is nil' do
        socket = mock "Socket"
        socket.should_receive(:connect).with("tcp://localhost:12345").and_return(nil)
        socket.should_receive(:recv_string).and_return({:request_type=>'echo',:payload=>'hello world'}.to_json)
        socket.should_receive(:send_string).with({:response_type=>'echo',:payload=>'hello world'}.to_json)
        ctx = mock "Context"
        ctx.should_receive(:socket).with(ZMQ::REP).and_return(socket)
        ZMQ::Context.should_receive(:new).and_return(ctx)
        @conn.connect_to_responder("tcp://localhost:12345")
        r = @conn.next_command {|from_server| {:response_type=>'echo',:payload=>'hello world'} }
        r.should be_true
      end
      it 'should get next command if not connected and socket is not nil' do
        socket = mock "Socket"
        socket.should_receive(:recv_string).and_return({:request_type=>'echo',:payload=>'hello world'}.to_json)
        socket.should_receive(:send_string).with({:response_type=>'echo',:payload=>'hello world'}.to_json)
        @conn.next_command(socket) {|from_server| {:response_type=>'echo',:payload=>'hello world'} }
      end
      it 'should return false if response is shutdown' do
        socket = mock "Socket"
        socket.should_receive(:recv_string).and_return({:request_type=>'echo',:payload=>'hello world'}.to_json)
        socket.should_receive(:send_string).with('shutdown'.to_json)
        r = @conn.next_command(socket) {|from_server| 'shutdown' }
        r.should be_false
      end
      it 'should prefer passed in socket to connected socket' do
        ignore_socket = mock "Socket"
        ignore_socket.stub(:connect)
        use_socket = mock "Socket"
        use_socket.should_receive(:recv_string).and_return({:request_type=>'echo',:payload=>'hello world'}.to_json)
        use_socket.should_receive(:send_string).with({:response_type=>'echo',:payload=>'hello world'}.to_json)
        ctx = mock "Context"
        ctx.should_receive(:socket).with(ZMQ::REP).and_return(ignore_socket)
        ZMQ::Context.should_receive(:new).and_return(ctx)
        @conn.connect_to_responder("tcp://localhost:12345")
        @conn.next_command(use_socket) {|from_server| {:response_type=>'echo',:payload=>'hello world'} }
      end
      it 'should pass a hash to block' do
        socket = mock "Socket"
        socket.stub(:recv_string).and_return({:request_type=>'echo',:payload=>'hello world'}.to_json)
        socket.stub(:send_string)
        @conn.next_command(socket) do |from_server|
          from_server['request_type'].should == 'echo'
          from_server['payload'].should == 'hello world'
          {'response_type'=>'echo',:payload=>'hello world'}
        end
      end
    end
  end
end
