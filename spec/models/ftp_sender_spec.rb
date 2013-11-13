require 'spec_helper'

describe FtpSender do
  before :each do
    @server = "abc"
    @username = "u"
    @password = "pwd"
    @content = "xyz"
    @file = Tempfile.new('abc')
    @file.write @content
    @file.flush
  end
  after :each do
    @file.close!
  end

  describe "default_options" do
    it "should have default options" do
     FtpSender.default_options(@file).should eq :binary => true, :passive => true, 
        :remote_file_name => File.basename(@file), :force_empty => false, :protocol => "ftp"
    end
  end

  describe "resend_file" do
    it "should deserialize json'ized options and call send_file" do 
      # Make sure to use symbols here since we want to make sure the options hash 
      # created from the json is an indifferent access one
      options = {:blah => "blah", :yada => "yada"}.to_json

      FtpSender.should_receive(:send_file) do |server, username, password, file, options|
        server.should eq @server
        username.should eq @username
        password.should eq @password
        file.should be_nil
        options['blah'].should eq "blah"
        options['yada'].should eq "yada"
      end

      FtpSender.resend_file @server, @username, @password, options
    end

    it "should resend a file using the session_id and attachment_id" do
      a = double("Attachment")
      Attachment.should_receive(:find).with(100).and_return a
      a.should_receive(:download_to_tempfile).and_yield @file

      s = FtpSession.create! username: 'test'
      opts = {'session_id' => s.id, 'attachment_id' => 100, 'remote_file_name'=>'test.txt'}

      @ftp = mock('ftp').as_null_object
      FtpSender.should_receive(:get_ftp_client).and_return @ftp
      @ftp.should_receive(:connect).with(@server, @username, @password, kind_of(Array)).and_yield @ftp
      @ftp.should_receive(:after_login).with(kind_of(Hash))
      @ftp.should_receive(:send_file).with @file.path, 'test.txt', kind_of(Hash)
      @ftp.stub(:last_response).and_return "200"

      session = FtpSender.resend_file @server, @username, @password, opts.to_json

      session.id.should eq s.id
      session.server.should eq @server
      session.username.should eq @username
      session.file_name.should eq 'test.txt'
    end
  end

  context :send do
    before :each do 
      @ftp = mock('ftp').as_null_object
      FtpSender.should_receive(:get_ftp_client).and_return @ftp
    end

    context :error do

      it "should log message and requeue if error is raised" do
        # These two lines mock out the actual internal client proxy access
        @ftp.should_receive(:connect).with(@server, @username, @password, kind_of(Array)).and_raise "RANDOM ERROR"
        @ftp.should_receive(:last_response).and_return "500"

        # We're stubbing out the create_attachment call on the ftp session to avoid S3 involvement when 
        # saving the ftp session's file attachment
        attachment = double("Attachment")
        attachment.stub(:id).and_return 1

        FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
        FtpSession.any_instance.should_receive(:attachment).twice.and_return attachment
        file_contents = nil
        attachment.should_receive(:attached=) { |file|
          file.rewind
          file_contents = file.read
        }

        # Mock out the requeue-ing on error via delayed jobs
        FtpSender.should_receive(:delay) do |args|
          # Just make sure the first requeue will re-run in under 10 seconds..we're testing the actual
          # calculate retry elsewhere
          (Time.zone.now - args[:run_at]).abs.should < 10
          FtpSender
        end
        session_id = nil
        FtpSender.should_receive(:resend_file) do |server, username, password, serialized_opts|
          server.should eq @server
          username.should eq @username
          password.should eq @password
          opts = ActiveSupport::JSON.decode serialized_opts
          opts['attachment_id'].should eq attachment.id
          opts['remote_file_name'].should eq File.basename(@file)
          session_id = opts['session_id']

          nil
        end
        StandardError.any_instance.should_receive(:log_me).with ["This exception email is only a warning. This ftp send attempt will be automatically retried."]
        
        sess = FtpSender.send_file @server, @username, @password, @file
        sess.username.should == @username
        sess.server.should == @server
        sess.file_name.should == File.basename(@file)
        sess.log.split("\n").last.should == "ERROR: RANDOM ERROR"
        file_contents.should == "xyz"
        sess.last_server_response.should == "500"
        # Make sure the correct session id was passed to the resend call
        session_id.should eq sess.id
        
        FtpSession.first.id.should == sess.id
        @file.closed?.should be_true
      end
    end
    
    context :success do 
      before :each do 
        @ftp.should_receive(:connect).with(@server, @username, @password, kind_of(Array)).and_yield @ftp
      end

      it "should log message if error is not raised" do
        # This just makes sure all the expected ftp proxy object calls are done
        @ftp.should_receive(:after_login).with(kind_of(Hash))
        @ftp.should_receive(:send_file).with @file.path, File.basename(@file), kind_of(Hash)
        @ftp.stub(:last_response).and_return "200"

        attachment = double("Attachment")
        FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
        file_contents = nil
        file_name = nil
        attachment.should_receive(:attached=) { |file|
          file.rewind
          file_contents = file.read
          file_name = file.original_filename
        }
        sess = FtpSender.send_file @server, @username, @password, @file
        sess.username.should == @username
        sess.server.should == @server
        sess.file_name.should == File.basename(@file)
        sess.log.split("\n").last.should == "Session completed successfully."
        file_contents.should == "xyz"
        file_name.should == File.basename(@file)
        sess.last_server_response.should == "200"
        @file.closed?.should be_true
      end

      it "should utilize remote_file_name option to send file under a different name" do
        @ftp.should_receive(:send_file).with @file.path, 'remote_file.txt', kind_of(Hash)
        @ftp.stub(:last_response).and_return "200"
        attachment = double("Attachment")
        FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
        file_contents = nil
        file_name = nil
        attachment.should_receive(:attached=) { |file|
          file.rewind
          file_contents = file.read
          file_name = file.original_filename
        }
        sess = FtpSender.send_file @server, @username, @password, @file, {:remote_file_name => 'remote_file.txt'}
        sess.file_name.should == 'remote_file.txt'
        sess.log.split("\n").last.should == "Session completed successfully."
        file_contents.should == "xyz"
        file_name.should == 'remote_file.txt'
      end

      it "should allow sending string file paths" do
        # Verify we end up closing the File object created internally
        handle = File.open(@file.path, "rb")
        File.should_receive(:open).with(@file.path, "rb").and_return handle

        @ftp.should_receive(:send_file).with @file.path, File.basename(@file), kind_of(Hash)
        @ftp.stub(:last_response).and_return "200"
        attachment = double("Attachment")
        FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
        file_contents = nil
        file_name = nil
        attachment.should_receive(:attached=) { |file|
          file.rewind
          file_contents = file.read
          file_name = file.original_filename
        }
        sess = FtpSender.send_file @server, @username, @password, @file.path
        sess.file_name.should == File.basename(@file)
        sess.log.split("\n").last.should == "Session completed successfully."
        file_contents.should == "xyz"
        file_name.should == File.basename(@file)
        handle.closed?.should be_true
      end

      it "should change directory to remote directory" do 
        @ftp.stub(:last_response).and_return "200"
        attachment = double("Attachment")
        FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
        attachment.should_receive(:attached=)
        @ftp.should_receive(:chdir).with("some/remote/folder")
        FtpSender.send_file @server, @username, @password, @file, {:folder => "some/remote/folder"}
      end
    end
  end

  context :FtpClient do
    before :each do
      @client = FtpSender::FtpClient.new
    end

    describe "connect" do
      it "should use Net::FTP to connect to a server and yield the given block" do
        @ftp = double("Net::FTP")
        Net::FTP.should_receive(:open).with(@server, @username, @password).and_yield @ftp

        test = nil

        @client.connect(@server, @username, @password, []) do |client|
          client.should be @client
          test = "Pass"
        end

        test.should eq "Pass"
      end
    end

    context :post_connect do
      before :each do 
        @ftp = double("Net::FTP")
        # connect sets up some variables so we need to call it every time
        Net::FTP.should_receive(:open).with(@server, @username, @password).and_yield @ftp
        @client.connect(@server, @username, @password, []){|client|}
      end

      describe "after_login" do
        it "should passivate" do
          @ftp.should_receive(:passive=).with(true)
          @client.after_login passive: true
          @client.log.should include "Set passive to true"
        end
      end

      describe "chdir" do
        it "should change directory" do
          @ftp.should_receive(:chdir).with("folder")
          @client.chdir "folder"
        end
      end

      describe "send_file" do
        it "should send text file" do
          @ftp.should_receive(:puttextfile).with("local", "remote")
          @client.send_file "local", "remote"
          @client.log.should include "Sending text file."
        end

        it "should send binary file" do
          @ftp.should_receive(:putbinaryfile).with("local", "remote")
          @client.send_file "local", "remote", binary: true
          @client.log.should include "Sending binary file."
        end
      end

      describe "last_repsonse" do
        it "should call last response" do
          @ftp.should_receive(:last_response).and_return "200"
          @client.last_response.should eq "200"
        end
      end
    end
    
  end

  context :SftpClient do
    before :each do
      @client = FtpSender::SftpClient.new
    end

    describe "connect" do
      it "should use Net::SFTP to connect to a server and yield the given block" do
        @ftp = double("Net::SFTP")
        Net::SFTP.should_receive(:start).with(@server, @username, password: @password, compression: true, paranoid: false).and_yield @ftp

        test = nil

        @client.connect(@server, @username, @password, []) do |client|
          client.should be @client
          test = "Pass"
        end

        test.should eq "Pass"
        @client.last_response.should eq "0 OK"
      end
    end

    context :post_connect do
      before :each do 
        @ftp = double("Net::SFTP")
        # connect sets up some variables so we need to call it every time
        Net::SFTP.should_receive(:start).with(@server, @username, password: @password, compression: true, paranoid: false).and_yield @ftp
        @client.connect(@server, @username, @password, []){|client|}
      end

      describe "chdir" do
        it "should change directory" do
          @client.chdir "folder"
          @client.remote_path.should eq Pathname.new 'folder'

          @client.chdir "subfolder"
          @client.remote_path.should eq Pathname.new 'folder/subfolder'

          @client.chdir "../another"
          @client.remote_path.should eq Pathname.new 'folder/another'
        end
      end

      describe "send_file" do
        it "should send a file" do
          @ftp.should_receive(:upload!).with "local", "remote"
          @client.send_file "local", "remote"
          @client.last_response.should eq "0 OK"
        end

        it "should send a file to a different directory" do
          @client.chdir "folder"
          @ftp.should_receive(:upload!).with "local", "folder/remote"
          @client.send_file "local", "remote"
          @client.last_response.should eq "0 OK"
        end

        it "should handle errors when uploading" do
          response = double("Net::SFTP::StatusException")
          response.stub(:code).and_return 4
          response.stub(:message).and_return "Error!"
          e = Net::SFTP::StatusException.new response

          @client.chdir "folder"
          @ftp.should_receive(:upload!).with("local", "folder/remote").and_raise e
          expect{@client.send_file "local", "remote"}.to raise_error Net::SFTP::StatusException
          @client.last_response.should eq "4 Error!"
        end
      end

      describe "last_repsonse" do
        # Technically, we've already been testing last_resonse througout the sftp tests so this one
        # is just very basic
        it "should call last response" do
          # Once the connect is called (as in the before block), the last response is set to ok
          @client.last_response.should eq "0 OK"
        end
      end
    end
    
  end

  context "empty file check" do
    
    before :each do
      @file.close!
      @file = Tempfile.new("empty")
      File.new(@file.path).size.should == 0
    end
    it "should not send empty file, but should still log messages" do
      FtpSender.should_not_receive(:get_ftp_client)
      sess = FtpSender.send_file @server, @username, @password, @file
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "File was empty, not sending."
      sess.attachment.should be_nil
    end
    it "should send empty file" do
      @ftp = mock('ftp').as_null_object
      FtpSender.should_receive(:get_ftp_client).and_return @ftp
      @ftp.should_receive(:connect).with(@server, @username, @password, kind_of(Array)).and_yield @ftp
      @ftp.stub(:last_response).and_return "200"

      attachment = double("Attachment")
      FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
      file_contents = nil
      attachment.should_receive(:attached=) { |file|
        file.rewind
        file_contents = file.read
      }
      sess = FtpSender.send_file @server, @username, @password, @file, :force_empty=>true
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      file_contents.should == ""
    end
  end
end
