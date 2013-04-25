require "spec_helper"

describe "FtpFileSupport" do
  class FtpSupportImpl 
    include OpenChain::FtpFileSupport

    def ftp_credentials
      return {:server=>'svr',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r'}
    end
  end

  describe :ftp_file do
    before :each do
      @t = mock('tmpfile')
      @t.stub(:path).and_return('/x.badfile')
    end

    it "should ftp_file" do
      File.stub(:exists?).and_return true
      @t.should_receive(:unlink)
      FtpSender.should_receive(:send_file).with('svr','u','p',@t,{:folder=>'f',:remote_file_name=>'r'})
      FtpSupportImpl.new.ftp_file @t
    end
    
    it 'should not unlink if false is passed' do
      File.stub(:exists?).and_return true
      @t.should_not_receive(:unlink)
      FtpSender.should_receive(:send_file).with('svr','u','p',@t,{:folder=>'f',:remote_file_name=>'r'})
      FtpSupportImpl.new.ftp_file @t, false
    end
    
    it "should return false if file is nil" do
      File.stub(:exists?).and_return true
      FtpSender.should_not_receive(:send_file)
      FtpSupportImpl.new.ftp_file(nil).should be_false
    end
    
    it "should return false if file does not exist" do
      FtpSender.should_not_receive(:send_file)
      FtpSupportImpl.new.ftp_file(@t).should be_false
    end

    it "should allow for missing folder and remote file name values from ftp_credentials" do
      ftp = FtpSupportImpl.new
      ftp.should_receive(:ftp_credentials).and_return(:server=>'svr',:username=>'u',:password=>'p')
      File.stub(:exists?).and_return true
      @t.should_receive(:unlink)
      FtpSender.should_receive(:send_file).with('svr','u','p',@t,{})
      ftp.ftp_file @t
    end
  end
end