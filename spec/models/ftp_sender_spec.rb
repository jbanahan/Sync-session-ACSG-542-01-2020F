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
     expect(FtpSender.default_options(@file, @file)).to eq({:binary => true, :passive => true,
        :remote_file_name => File.basename(@file), :force_empty => false, :protocol => "ftp"}.with_indifferent_access)
    end

    it "uses the original_filename method on the file object if present to make the remote_file_name option" do
      Attachment.add_original_filename_method @file
      @file.original_filename="original.txt"

      expect(FtpSender.default_options(@file, @file)).to eq({:binary => true, :passive => true,
         :remote_file_name => "original.txt", :force_empty => false, :protocol => "ftp"}.with_indifferent_access)
    end
  end

  describe "resend_file" do
    it "should deserialize json'ized options and call send_file" do
      # Make sure to use symbols here since we want to make sure the options hash
      # created from the json is an indifferent access one
      options = {:blah => "blah", :yada => "yada"}.to_json

      expect(FtpSender).to receive(:send_file) do |server, username, password, file, options|
        expect(server).to eq @server
        expect(username).to eq @username
        expect(password).to eq @password
        expect(file).to be_nil
        expect(options['blah']).to eq "blah"
        expect(options['yada']).to eq "yada"
      end

      FtpSender.resend_file @server, @username, @password, options
    end

    it "should resend a file using the session_id and attachment_id" do
      a = double("Attachment")
      expect(Attachment).to receive(:find).with(100).and_return a
      expect(a).to receive(:download_to_tempfile).and_yield @file

      s = FtpSession.create! username: 'test'
      opts = {'session_id' => s.id, 'attachment_id' => 100, 'remote_file_name'=>'test.txt'}

      @ftp = double('ftp').as_null_object
      expect(FtpSender).to receive(:get_ftp_client).and_return @ftp
      expect(@ftp).to receive(:connect).with(@server, @username, @password, kind_of(Array), kind_of(Hash)).and_yield @ftp
      expect(@ftp).to receive(:after_login).with(kind_of(Hash))
      expect(@ftp).to receive(:send_file).with @file.path, 'test.txt', kind_of(Hash)
      allow(@ftp).to receive(:last_response).and_return "200"

      session = FtpSender.resend_file @server, @username, @password, opts.to_json

      expect(session.id).to eq s.id
      expect(session.server).to eq @server
      expect(session.username).to eq @username
      expect(session.file_name).to eq 'test.txt'
    end
  end

  context "send" do
    before :each do
      @ftp = instance_double(described_class::NoOpFtpClient).as_null_object
      allow(FtpSender).to receive(:get_ftp_client).and_return @ftp
    end

    context "error" do

      before :each do
        allow(MasterSetup).to receive(:ftp_enabled?).and_return true
      end

      it "should log message and requeue if error is raised" do
        # These two lines mock out the actual internal client proxy access
        expect(@ftp).to receive(:connect).with(@server, @username, @password, kind_of(Array), kind_of(Hash)).and_raise "RANDOM ERROR"
        expect(@ftp).to receive(:last_response).and_return "500"

        # We're stubbing out the build_attachment call on the ftp session to avoid S3 involvement when
        # saving the ftp session's file attachment
        attachment = double("Attachment")
        allow(attachment).to receive(:id).and_return 1

        expect_any_instance_of(FtpSession).to receive(:build_attachment).and_return attachment
        expect_any_instance_of(FtpSession).to receive(:attachment).twice.and_return attachment
        file_contents = nil
        expect(attachment).to receive(:attached=) { |file|
          file.rewind
          file_contents = file.read
        }

        # Mock out the requeue-ing on error via delayed jobs
        expect(FtpSender).to receive(:delay) do |args|
          # Just make sure the first requeue will re-run in under 10 seconds..we're testing the actual
          # calculate retry elsewhere
          expect((Time.zone.now - args[:run_at]).abs).to be < 10
          FtpSender
        end
        session_id = nil
        expect(FtpSender).to receive(:resend_file) do |server, username, password, serialized_opts|
          expect(server).to eq @server
          expect(username).to eq @username
          expect(password).to eq @password
          opts = ActiveSupport::JSON.decode serialized_opts
          expect(opts['attachment_id']).to eq attachment.id
          expect(opts['remote_file_name']).to eq File.basename(@file)
          session_id = opts['session_id']

          nil
        end
        sess = FtpSender.send_file @server, @username, @password, @file
        expect(sess.username).to eq(@username)
        expect(sess.server).to eq(@server)
        expect(sess.file_name).to eq(File.basename(@file))
        expect(sess.log.split("\n").last).to eq("ERROR: RANDOM ERROR")
        expect(file_contents).to eq("xyz")
        expect(sess.last_server_response).to eq("500")
        # Make sure the correct session id was passed to the resend call
        expect(session_id).to eq sess.id

        expect(FtpSession.first.id).to eq(sess.id)
        expect(@file.closed?).to be_truthy
      end

      it "should log message and requeue if error is raised, but last response was a success" do
        # These two lines mock out the actual internal client proxy access
        expect(@ftp).to receive(:connect).with(@server, @username, @password, kind_of(Array), kind_of(Hash)).and_raise "RANDOM ERROR"
        expect(@ftp).to receive(:last_response).and_return "200"

        # We're stubbing out the build_attachment call on the ftp session to avoid S3 involvement when
        # saving the ftp session's file attachment
        attachment = double("Attachment")
        allow(attachment).to receive(:id).and_return 1

        expect_any_instance_of(FtpSession).to receive(:build_attachment).and_return attachment
        expect_any_instance_of(FtpSession).to receive(:attachment).twice.and_return attachment
        file_contents = nil
        expect(attachment).to receive(:attached=) { |file|
          file.rewind
          file_contents = file.read
        }

        # Mock out the requeue-ing on error via delayed jobs
        expect(FtpSender).to receive(:delay) do |args|
          # Just make sure the first requeue will re-run in under 10 seconds..we're testing the actual
          # calculate retry elsewhere
          expect((Time.zone.now - args[:run_at]).abs).to be < 10
          FtpSender
        end
        session_id = nil
        expect(FtpSender).to receive(:resend_file) do |server, username, password, serialized_opts|
          expect(server).to eq @server
          expect(username).to eq @username
          expect(password).to eq @password
          opts = ActiveSupport::JSON.decode serialized_opts
          expect(opts['attachment_id']).to eq attachment.id
          expect(opts['remote_file_name']).to eq File.basename(@file)
          session_id = opts['session_id']

          nil
        end
        sess = FtpSender.send_file @server, @username, @password, @file
        expect(sess.username).to eq(@username)
        expect(sess.server).to eq(@server)
        expect(sess.file_name).to eq(File.basename(@file))
        expect(sess.log.split("\n").last).to eq("ERROR: RANDOM ERROR")
        expect(file_contents).to eq("xyz")
        expect(sess.last_server_response).to eq("200")
        # Make sure the correct session id was passed to the resend call
        expect(session_id).to eq sess.id

        expect(FtpSession.first.id).to eq(sess.id)
        expect(@file.closed?).to be_truthy
      end

      it "sends a failure email on the 10th failure" do
        s = FtpSession.create! username: 'test', retry_count: 10
        opts = {'session_id' => s.id, 'attachment_id' => 100, 'remote_file_name'=>'test.txt'}
        a = double("Attachment")
        expect(Attachment).to receive(:find).with(100).and_return a
        expect(a).to receive(:download_to_tempfile).and_yield @file
        attachment = double("Attachment")
        allow_any_instance_of(FtpSession).to receive(:attachment).and_return attachment

        expect(@ftp).to receive(:connect).and_raise StandardError, "Error!"
        expect(@ftp).to receive(:last_response).and_return "Error"

        FtpSender.send_file 'server', 'user', 'password', nil, opts
        expect(ErrorLogEntry.last.additional_messages).to eq ["Attempted and failed to send ftp Session id #{s.id} 10 times. No more attempts will be made."]

      end

      it "does not queue send retry if ftp is not enabled" do
        allow(MasterSetup).to receive(:ftp_enabled?).and_return false
        # Raise an error early in the send block, since all we care about is that the resend isn't queued
        allow(FtpSender).to receive(:get_ftp_client).and_raise "Error"
        expect(FtpSender).not_to receive(:delay)
        allow(@ftp).to receive(:last_response).and_return "500"

        FtpSender.send_file 'server', 'user', 'password', @file, {}
      end
    end

    context "success" do
      before :each do
        expect(@ftp).to receive(:connect).with(@server, @username, @password, kind_of(Array), kind_of(Hash)).and_yield @ftp
      end

      it "should log message if error is not raised" do
        # This just makes sure all the expected ftp proxy object calls are done
        expect(@ftp).to receive(:after_login).with(kind_of(Hash))
        expect(@ftp).to receive(:send_file).with @file.path, File.basename(@file), kind_of(Hash)
        allow(@ftp).to receive(:last_response).and_return "200"

        attachment = double("Attachment")
        expect_any_instance_of(FtpSession).to receive(:build_attachment).and_return attachment
        file_contents = nil
        file_name = nil
        expect(attachment).to receive(:attached=) { |file|
          file.rewind
          file_contents = file.read
          file_name = file.original_filename
        }
        sess = FtpSender.send_file @server, @username, @password, @file
        expect(sess.username).to eq(@username)
        expect(sess.server).to eq(@server)
        expect(sess.file_name).to eq(File.basename(@file))
        expect(sess.log.split("\n").last).to eq("Session completed successfully.")
        expect(file_contents).to eq("xyz")
        expect(file_name).to eq(File.basename(@file))
        expect(sess.last_server_response).to eq("200")
        expect(@file.closed?).to be_truthy
      end

      it "should utilize remote_file_name option to send file under a different name" do
        expect(@ftp).to receive(:send_file).with @file.path, 'remote_file.txt', kind_of(Hash)
        allow(@ftp).to receive(:last_response).and_return "200"
        attachment = double("Attachment")
        expect_any_instance_of(FtpSession).to receive(:build_attachment).and_return attachment
        file_contents = nil
        file_name = nil
        expect(attachment).to receive(:attached=) { |file|
          file.rewind
          file_contents = file.read
          file_name = file.original_filename
        }
        sess = FtpSender.send_file @server, @username, @password, @file, {:remote_file_name => 'remote_file.txt'}
        expect(sess.file_name).to eq('remote_file.txt')
        expect(sess.log.split("\n").last).to eq("Session completed successfully.")
        expect(file_contents).to eq("xyz")
        expect(file_name).to eq('remote_file.txt')
      end

      it "should allow sending string file paths" do
        # Verify we end up closing the File object created internally
        handle = File.open(@file.path, "rb")
        expect(File).to receive(:open).with(@file.path, "rb").and_return handle

        expect(@ftp).to receive(:send_file).with @file.path, File.basename(@file), kind_of(Hash)
        allow(@ftp).to receive(:last_response).and_return "200"
        attachment = double("Attachment")
        expect_any_instance_of(FtpSession).to receive(:build_attachment).and_return attachment
        file_contents = nil
        file_name = nil
        expect(attachment).to receive(:attached=) { |file|
          file.rewind
          file_contents = file.read
          file_name = file.original_filename
        }
        sess = FtpSender.send_file @server, @username, @password, @file.path
        expect(sess.file_name).to eq(File.basename(@file))
        expect(sess.log.split("\n").last).to eq("Session completed successfully.")
        expect(file_contents).to eq("xyz")
        expect(file_name).to eq(File.basename(@file))
        expect(handle.closed?).to be_truthy
      end

      it "should change directory to remote directory" do
        allow(@ftp).to receive(:last_response).and_return "200"
        attachment = double("Attachment")
        expect_any_instance_of(FtpSession).to receive(:build_attachment).and_return attachment
        expect(attachment).to receive(:attached=)
        expect(@ftp).to receive(:chdir).with("some/remote/folder")
        FtpSender.send_file @server, @username, @password, @file, {:folder => "some/remote/folder"}
      end

      it 'uses the file arguments original_filename method for the default file name' do
        Attachment.add_original_filename_method @file
        @file.original_filename = "original.txt"

        allow(@ftp).to receive(:last_response).and_return "200"
        attachment = double("Attachment")
        expect_any_instance_of(FtpSession).to receive(:build_attachment).and_return attachment
        expect(attachment).to receive(:attached=)
        session = FtpSender.send_file @server, @username, @password, @file
        expect(session.file_name).to eq("original.txt")
      end
    end

    context "with blank file" do

      before :each do 
        @file.truncate(0)
        @file.rewind
      end

      it "does not save ftp_sessions for blank files" do
        sess = FtpSender.send_file @server, @username, @password, @file
        expect(sess.persisted?).to eq false
        expect(sess.username).to eq(@username)
        expect(sess.server).to eq(@server)
        expect(sess.file_name).to eq(File.basename(@file))
        expect(sess.empty_file?).to eq true
        expect(sess.last_server_response).to be_nil
        expect(sess.successful?).to eq true

        expect(@file.closed?).to be_truthy
      end
    end

    context "validate_connect" do
      it "passes through all the opts to the connect method" do
        def @file.original_filename; 'myfile.txt'; end

        local_opts = {port: 1234, binary: false, passive: false, remote_file_name: "filename.txt", force_empty: true, protocol: "sftp", folder: "folder"}
        expect(@ftp).to receive(:connect).with(@server, @username, @password, kind_of(Array), local_opts.with_indifferent_access).and_yield @ftp
        expect(@ftp).to receive(:after_login).with(kind_of(Hash))
        allow(@ftp).to receive(:last_response).and_return "200"

        session = double("Session").as_null_object
        allow(session).to receive(:successful?).and_return true
        expect(FtpSender).to receive(:find_ftp_session).and_return session

        file = double('File')
        allow(file).to receive(:path).and_return "/not/a/real/file.txt"
        expect(FtpSender).to receive(:get_file_to_ftp).and_yield file

        FtpSender.send_file @server, @username, @password, @file, local_opts
      end
    end
  end

  context "FtpClient" do
    before :each do
      @client = FtpSender::FtpClient.new
    end

    describe "connect" do
      it "should use Net::FTP to connect to a server and yield the given block" do
        @ftp = double("Net::FTP")
        allow(@ftp).to receive(:close)
        expect(Net::FTP).to receive(:new).and_return(@ftp)
        expect(@ftp).to receive(:connect).with(@server, "21").and_return(@ftp)
        expect(@ftp).to receive(:login).with(@username, @password).and_return(@ftp)

        test = nil

        @client.connect(@server, @username, @password, [], {}) do |client|
          expect(client).to be @client
          test = "Pass"
        end

        expect(test).to eq "Pass"
      end
    end

    context "post_connect" do
      before :each do
        @ftp = double("Net::FTP")
        allow(@ftp).to receive(:close)
        expect(Net::FTP).to receive(:new).and_return(@ftp)
        expect(@ftp).to receive(:connect).with(@server, "21").and_return(@ftp)
        expect(@ftp).to receive(:login).with(@username, @password).and_return(@ftp)
        # connect sets up some variables so we need to call it every time
        @client.connect(@server, @username, @password, [], {}){|client|}
      end

      describe "after_login" do
        it "should passivate" do
          expect(@ftp).to receive(:passive=).with(true)
          @client.after_login passive: true
          expect(@client.log).to include "Set passive to true"
        end
      end

      describe "chdir" do
        it "should change directory" do
          expect(@ftp).to receive(:chdir).with("folder")
          @client.chdir "folder"
        end
      end

      describe "send_file" do
        it "should send text file" do
          expect(@ftp).to receive(:puttextfile).with("local", "remote")
          @client.send_file "local", "remote"
          expect(@client.log).to include "Sending text file."
        end

        it "should send binary file" do
          expect(@ftp).to receive(:putbinaryfile).with("local", "remote")
          @client.send_file "local", "remote", binary: true
          expect(@client.log).to include "Sending binary file."
        end
      end

      describe "last_repsonse" do
        it "should call last response" do
          expect(@ftp).to receive(:last_response).and_return "200"
          expect(@client.last_response).to eq "200"
        end
      end

      describe "list_files" do
        let (:file) {
          f = double("MlsdFileEntry")
          allow(f).to receive(:file?).and_return true
          allow(f).to receive(:pathname).and_return "file.txt"
          allow(f).to receive(:size).and_return 1
          # This is purposely a Time, as that's what's returned by the mlsd ftp listing
          allow(f).to receive(:modify).and_return Time.now

          f
        }

        let (:directory) {
          f = double("MlsdFileEntry")
          allow(f).to receive(:file?).and_return false
          allow(f).to receive(:pathname).and_return "directory"
          allow(f).to receive(:size).and_return 0
          # This is purposely a Time, as that's what's returned by the mlsd ftp listing
          allow(f).to receive(:modify).and_return Time.now

          f
        }

        it "uses mlsd command and only returns files by default" do
          expect(@ftp).to receive(:mlsd).and_return [file, directory]

          files = @client.list_files
          expect(files.length).to eq 1
          f = files[0]
          expect(f.name).to eq "file.txt"
          expect(f.size).to eq 1
          expect(f.file?).to eq true
          expect(f.directory?).to eq false
          expect(f.mtime).to eq file.modify.in_time_zone("UTC")
        end

        it "converts to another timezone if specified" do
          expect(@ftp).to receive(:mlsd).and_return [file]

          files = @client.list_files convert_to_time_zone: "America/New_York"
          expect(files.length).to eq 1
          f = files[0]
          expect(f.mtime).to eq file.modify.in_time_zone("America/New_York")
        end

        it "includes directories if specified" do 
          expect(@ftp).to receive(:mlsd).and_return [file, directory]

          files = @client.list_files include_only_files: false
          expect(files.length).to eq 2
          f = files[1]
          expect(f.name).to eq "directory"
          expect(f.size).to eq 0
          expect(f.file?).to eq false
          expect(f.directory?).to eq true
          expect(f.mtime).to eq directory.modify.in_time_zone("UTC")
        end
      end
    end

  end

  context "SftpClient" do
    before :each do
      @client = FtpSender::SftpClient.new
    end

    describe "connect" do
      it "should use Net::SFTP to connect to a server and yield the given block" do
        @ftp = double("Net::SFTP")
        expect(Net::SFTP).to receive(:start).with(@server, @username, password: @password, compression: false, verify_host_key: false, timeout: 10, auth_methods: ["password"]).and_yield @ftp

        test = nil

        @client.connect(@server, @username, @password, [], {}) do |client|
          expect(client).to be @client
          test = "Pass"
        end

        expect(test).to eq "Pass"
        expect(@client.last_response).to eq "0 OK"
      end

      it "should allow a different port to be specified" do
        @ftp = double("Net::SFTP")
        expect(Net::SFTP).to receive(:start).with(@server, @username, hash_including(port: 1234)).and_yield @ftp

        test = nil

        @client.connect(@server, @username, @password, [], {port: 1234}) do |client|
          expect(client).to be @client
          test = "Pass"
        end

        expect(test).to eq "Pass"
        expect(@client.last_response).to eq "0 OK"
      end

      it "handles disconnect errors" do
        @ftp = double("Net::SFTP")
        expect(Net::SFTP).to receive(:start).and_yield @ftp

        expect(@client).to receive(:session_completed?).and_return true

        @client.connect(@server, @username, @password, [], {}) {|client| raise Net::SSH::Disconnect}
        expect(@client.last_response).to eq "0 OK"
      end

      it "handles re-raises disconnect errors if session didn't complete normally" do
        @ftp = double("Net::SFTP")
        expect(Net::SFTP).to receive(:start).and_yield @ftp

        expect(@client).to receive(:session_completed?).and_return false

        expect{@client.connect(@server, @username, @password, [], {}) {|client| raise Net::SSH::Disconnect, "Error Message"}}.to raise_error Net::SSH::Disconnect, "Error Message"
        expect(@client.last_response).to eq "4 Error Message"
      end

      it "uses compression for connections to connect.vfitrack.net" do
        @server = "connect.vfitrack.net"
        @ftp = double("Net::SFTP")
        expect(Net::SFTP).to receive(:start).with(@server, @username, password: @password, compression: true, verify_host_key: false, timeout: 10, auth_methods: ["password"]).and_yield @ftp
        @client.connect(@server, @username, @password, [], {}) {|c| }
      end

      it "uses compression for connections to ftp2.vandegriftinc.com" do
        @server = "ftp2.vandegriftinc.com"
        @ftp = double("Net::SFTP")
        expect(Net::SFTP).to receive(:start).with(@server, @username, password: @password, compression: true, verify_host_key: false, timeout: 10, auth_methods: ["password"]).and_yield @ftp
        @client.connect(@server, @username, @password, [], {}) {|c| }
      end
    end

    context "post_connect" do
      before :each do
        @ftp = double("Net::SFTP")
        # connect sets up some variables so we need to call it every time
        expect(Net::SFTP).to receive(:start).and_yield @ftp
        @client.connect(@server, @username, @password, [], {}){|client|}
      end

      describe "chdir" do
        it "should change directory" do
          @client.chdir "folder"
          expect(@client.remote_path).to eq Pathname.new 'folder'

          @client.chdir "subfolder"
          expect(@client.remote_path).to eq Pathname.new 'folder/subfolder'

          @client.chdir "../another"
          expect(@client.remote_path).to eq Pathname.new 'folder/another'
        end
      end

      describe "send_file" do
        it "should send a file" do
          expect(@ftp).to receive(:upload!).with "local", "remote"
          @client.send_file "local", "remote"
          expect(@client.last_response).to eq "0 OK"
        end

        it "should send a file to a different directory" do
          @client.chdir "folder"
          expect(@ftp).to receive(:upload!).with "local", "folder/remote"
          @client.send_file "local", "remote"
          expect(@client.last_response).to eq "0 OK"
        end

        it "should handle errors when uploading" do
          response = double("Net::SFTP::StatusException")
          allow(response).to receive(:code).and_return 4
          allow(response).to receive(:message).and_return "Error!"
          e = Net::SFTP::StatusException.new response

          @client.chdir "folder"
          expect(@ftp).to receive(:upload!).with("local", "folder/remote").and_raise e
          begin
            @client.send_file "local", "remote"
            fail("Should have raise error.")
          rescue => e
            # Make sure we're clearing out the response object when handling the exception internally
            expect(e.response).to be_nil
          end
          expect(@client.last_response).to eq "4 Error!"
        end
      end

      describe "last_repsonse" do
        # Technically, we've already been testing last_resonse througout the sftp tests so this one
        # is just very basic
        it "should call last response" do
          # Once the connect is called (as in the before block), the last response is set to ok
          expect(@client.last_response).to eq "0 OK"
        end
      end

      describe "list_files" do
        let (:file) {
          f = double("SftpFileEntry")
          allow(f).to receive(:file?).and_return true
          allow(f).to receive(:name).and_return "file.txt"
          attributes = double("SftpFileAttributes")
          allow(attributes).to receive(:size).and_return 1
          # This is purposely a Time, as that's what's returned by the mlsd ftp listing
          allow(attributes).to receive(:mtime).and_return Time.now
          allow(f).to receive(:attributes).and_return attributes
          
          f
        }

        let (:directory) {
          f = double("SftpFileEntry")
          allow(f).to receive(:file?).and_return false
          allow(f).to receive(:name).and_return "directory"
          attributes = double("SftpFileAttributes")
          allow(attributes).to receive(:size).and_return 0
          # This is purposely a Time, as that's what's returned by the mlsd ftp listing
          allow(attributes).to receive(:mtime).and_return Time.now
          allow(f).to receive(:attributes).and_return attributes

          f
        }

        let (:dir_command) {
          c = double("SftpDirCommand")
        }

        it "uses directory listing command and only returns files by default" do
          expect(@ftp).to receive(:dir).and_return dir_command
          expect(dir_command).to receive(:entries).with("").and_return [file, directory]

          files = @client.list_files
          expect(files.length).to eq 1
          f = files[0]
          expect(f.name).to eq "file.txt"
          expect(f.size).to eq 1
          expect(f.file?).to eq true
          expect(f.directory?).to eq false
          expect(f.mtime).to eq file.attributes.mtime.in_time_zone("UTC")
        end

        it "converts to another timezone if specified" do
          expect(@ftp).to receive(:dir).and_return dir_command
          expect(dir_command).to receive(:entries).with("").and_return [file]

          files = @client.list_files convert_to_time_zone: "America/New_York"
          expect(files.length).to eq 1
          f = files[0]
          expect(f.mtime).to eq file.attributes.mtime.in_time_zone("America/New_York")
        end

        it "includes directories if specified" do 
          expect(@ftp).to receive(:dir).and_return dir_command
          expect(dir_command).to receive(:entries).with("").and_return [file, directory]

          files = @client.list_files include_only_files: false
          expect(files.length).to eq 2
          f = files[1]
          expect(f.name).to eq "directory"
          expect(f.size).to eq 0
          expect(f.file?).to eq false
          expect(f.directory?).to eq true
          expect(f.mtime).to eq directory.attributes.mtime.in_time_zone("UTC")
        end
      end
    end

  end

  context "empty file check" do

    before :each do
      @file.close!
      @file = Tempfile.new("empty")
      expect(File.new(@file.path).size).to eq(0)
    end
    it "should not send empty file, but should still log messages" do
      expect(FtpSender).not_to receive(:get_ftp_client)
      sess = FtpSender.send_file @server, @username, @password, @file
      expect(sess.username).to eq(@username)
      expect(sess.server).to eq(@server)
      expect(sess.file_name).to eq(File.basename(@file))
      expect(sess.log.split("\n").last).to eq("File was empty, not sending.")
      expect(sess.attachment).to be_nil
    end
    it "should send empty file" do
      @ftp = double('ftp').as_null_object
      expect(FtpSender).to receive(:get_ftp_client).and_return @ftp
      expect(@ftp).to receive(:connect).with(@server, @username, @password, kind_of(Array), kind_of(Hash)).and_yield @ftp
      allow(@ftp).to receive(:last_response).and_return "200"

      attachment = double("Attachment")
      expect_any_instance_of(FtpSession).to receive(:build_attachment).and_return attachment
      file_contents = nil
      expect(attachment).to receive(:attached=) { |file|
        file.rewind
        file_contents = file.read
      }
      sess = FtpSender.send_file @server, @username, @password, @file, :force_empty=>true
      expect(sess.username).to eq(@username)
      expect(sess.server).to eq(@server)
      expect(sess.file_name).to eq(File.basename(@file))
      expect(file_contents).to eq("")
    end
  end

  describe "get_ftp_client" do
    it "returns a no-op client if MasterSetup#ftp_enabled? is false" do
      expect(MasterSetup).to receive(:ftp_enabled?).and_return false
      expect(FtpSender.send(:get_ftp_client, {}).class.name).to eq "FtpSender::NoOpFtpClient"
    end

    it "returns an ftp client by default" do
      expect(MasterSetup).to receive(:ftp_enabled?).and_return true
      expect(FtpSender.send(:get_ftp_client, {}).class.name).to eq "FtpSender::FtpClient"
    end

    it "returns an sftp client if requested" do
      expect(MasterSetup).to receive(:ftp_enabled?).and_return true
      expect(FtpSender.send(:get_ftp_client, {protocol: 'sftp'}).class.name).to eq "FtpSender::SftpClient"
    end
  end
end
