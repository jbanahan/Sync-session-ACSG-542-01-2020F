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
      FtpSender.send_file @server, @username, "pwd", @file
      sess = FtpSession.first
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "ERROR: RANDOM ERROR"
      sess.data.should == 'xyz'
    end
    it "should log message if error is not raised" do
      FtpSender.send_file @server, @username, "pwd", @file
      sess = FtpSession.first
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "Session completed successfully."
      sess.data.should == 'xyz'
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
      FtpSender.send_file @server, @username, "pwd", @file
      sess = FtpSession.first
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
      sess.log.split("\n").last.should == "File was empty, not sending."
      sess.data.should be_nil
    end
    it "should send empty file" do
      @ftp = mock('ftp').as_null_object
      @ftp.should_receive(:putbinaryfile)
      Net::FTP.should_receive(:open).with(@server).and_yield(@ftp)
      FtpSender.send_file @server, @username, "pwd", @file, :force_empty=>true
      sess = FtpSession.first
      sess.username.should == @username
      sess.server.should == @server
      sess.file_name.should == File.basename(@file)
    end
  end
end
