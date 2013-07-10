require 'spec_helper'

describe FtpSender do
  before :each do
    @server = "abc"
    @username = "u"
    @content = "xyz"
    @file = Tempfile.new('abc')
    @file.write @content
    @file.flush
  end
  after :each do
    @file.unlink
  end
  context :send do
    before :each do
      @ftp = mock('ftp').as_null_object
      Net::FTP.should_receive(:open).with(@server).and_yield(@ftp)
    end

    it "should log message if error is raised" do
      @ftp.stub(:login).and_raise("RANDOM ERROR")
      @ftp.stub(:last_response).and_return "500"
      # We're stubbing out the create_attachment call on the ftp session to avoid S3 involvement when 
      # saving the ftp session's file attachment
      attachment = double("Attachment")
      FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
      file_contents = nil
      attachment.should_receive(:attached=) { |file|
        file.rewind
        file_contents = file.read
      }

      sess = FtpSender.send_file @server, @username, "pwd", @file
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "ERROR: RANDOM ERROR"
      file_contents.should == "xyz"
      sess.last_server_response.should == "500"
      
      FtpSession.first.id.should == sess.id
    end
    it "should log message if error is not raised" do
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
      sess = FtpSender.send_file @server, @username, "pwd", @file
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "Session completed successfully."
      file_contents.should == "xyz"
      file_name.should == File.basename(@file)
      sess.last_server_response.should == "200"
    end

    it "should utilize remote_file_name option to send file under a different name" do
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
      sess = FtpSender.send_file @server, @username, "pwd", @file, {:remote_file_name => 'remote_file.txt'}
      sess.file_name.should == 'remote_file.txt'
      sess.log.split("\n").last.should == "Session completed successfully."
      file_contents.should == "xyz"
      file_name.should == 'remote_file.txt'
    end

    it "should allow sending string file paths" do
      # Verify we end up closing the File object created internally
      File.any_instance.should_receive(:close)
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
      sess = FtpSender.send_file @server, @username, "pwd", @file.path
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "Session completed successfully."
      file_contents.should == "xyz"
      file_name.should == File.basename(@file)
    end

    it "should change directory to remote directory" do 
      @ftp.stub(:last_response).and_return "200"
      attachment = double("Attachment")
      FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
      attachment.should_receive(:attached=)
      @ftp.should_receive(:chdir).with("some/remote/folder")
      FtpSender.send_file @server, @username, "pwd", @file, {:folder => "some/remote/folder"}
    end

    it "should send in binary mode by default" do 
      @ftp.stub(:last_response).and_return "200"
      attachment = double("Attachment")
      FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
      attachment.should_receive(:attached=)
      @ftp.should_receive(:putbinaryfile).with(@file, File.basename(@file))
      FtpSender.send_file @server, @username, "pwd", @file
    end

    it "should send in text mode when specified" do 
      @ftp.stub(:last_response).and_return "200"
      attachment = double("Attachment")
      FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
      attachment.should_receive(:attached=)
      @ftp.should_receive(:puttextfile).with(@file, File.basename(@file))
      FtpSender.send_file @server, @username, "pwd", @file, {:binary => false}
    end

    it "should passivate by default" do
      @ftp.stub(:last_response).and_return "200"
      attachment = double("Attachment")
      FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
      attachment.should_receive(:attached=)
      @ftp.should_receive(:passive=).with(true)
      FtpSender.send_file @server, @username, "pwd", @file
    end

    it "should use active ftp when specified" do
      @ftp.stub(:last_response).and_return "200"
      attachment = double("Attachment")
      FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
      attachment.should_receive(:attached=)
      @ftp.should_receive(:passive=).with(false)
      FtpSender.send_file @server, @username, "pwd", @file, {:passive=>false}
    end
  end

  context "empty file check" do
    
    before :each do
      @file.unlink
      @file = Tempfile.new("empty")
      File.new(@file.path).size.should == 0
    end
    it "should not send empty file, but should still log messages" do
      Net::FTP.should_not_receive(:open)
      sess = FtpSender.send_file @server, @username, "pwd", @file
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "File was empty, not sending."
      sess.attachment.should be_nil
    end
    it "should send empty file" do
      @ftp = mock('ftp').as_null_object
      @ftp.should_receive(:putbinaryfile)
      Net::FTP.should_receive(:open).with(@server).and_yield(@ftp)
      @ftp.stub(:last_response).and_return "200"
      attachment = double("Attachment")
      FtpSession.any_instance.should_receive(:create_attachment).and_return attachment
      file_contents = nil
      attachment.should_receive(:attached=) { |file|
        file.rewind
        file_contents = file.read
      }
      sess = FtpSender.send_file @server, @username, "pwd", @file, :force_empty=>true
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      file_contents.should == ""
    end
  end
end
