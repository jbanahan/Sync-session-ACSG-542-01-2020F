require 'spec_helper'

describe FtpSender do
  before :each do
    @server = "abc"
    @username = "u"
    @content = "xyz"
    @file = Tempfile.new('abc')
    @file.write @content
    @file.flush
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
