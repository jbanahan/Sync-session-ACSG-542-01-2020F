require 'spec_helper'
require 'open_chain/s3'

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
      sess = FtpSender.send_file @server, @username, "pwd", @file
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "ERROR: RANDOM ERROR"
      OpenChain::S3.get_data('chain-io', sess.attachment.attached.path).should == "xyz"
      sess.last_server_response.should == "500"
      
      FtpSession.first.id.should == sess.id
    end
    it "should log message if error is not raised" do
      @ftp.stub(:last_response).and_return "200"
      sess = FtpSender.send_file @server, @username, "pwd", @file
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "Session completed successfully."
      OpenChain::S3.get_data('chain-io', sess.attachment.attached.path).should == "xyz"
      sess.attachment.attached_file_name.should == File.basename(@file)
      sess.last_server_response.should == "200"
    end

    it "should utilize remote_file_name option to send file under a different name" do
      @ftp.stub(:last_response).and_return "200"
      sess = FtpSender.send_file @server, @username, "pwd", @file, {:remote_file_name => 'remote_file.txt'}
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == 'remote_file.txt'
      sess.log.split("\n").last.should == "Session completed successfully."
      OpenChain::S3.get_data('chain-io', sess.attachment.attached.path).should == "xyz"
      sess.attachment.attached_file_name.should == 'remote_file.txt'
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
      sess = FtpSender.send_file @server, @username, "pwd", @file, :force_empty=>true
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.attachment.should_not be_nil
      OpenChain::S3.get_data('chain-io', sess.attachment.attached.path).should == ""
    end
  end
end
