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

    it "should take option_overrides" do
      File.stub(:exists?).and_return true
      FtpSender.should_receive(:send_file).with('otherserver','u','p',@t,{:folder=>'f',:remote_file_name=>'r'})
      @t.should_receive(:unlink)
      FtpSupportImpl.new.ftp_file @t, {server:'otherserver'}
    end
    
    it 'should not unlink if false is passed' do
      File.stub(:exists?).and_return true
      @t.should_not_receive(:unlink)
      FtpSender.should_receive(:send_file).with('svr','u','p',@t,{:folder=>'f',:remote_file_name=>'r'})
      FtpSupportImpl.new.ftp_file @t, {keep_local:true}
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

  describe :ftp2_vandegrift_inc do

    it "should use the correct credentials for ftp2 server" do
      c = FtpSupportImpl.new.ftp2_vandegrift_inc 'folder'
      c[:server].should eq 'ftp2.vandegriftinc.com'
      c[:username].should eq 'VFITRACK'
      c[:password].should eq 'RL2VFftp'
      c[:folder].should eq 'folder'
      c[:remote_file_name].should be_nil
    end

    it "should add remote filename when given" do
      c = FtpSupportImpl.new.ftp2_vandegrift_inc 'folder', 'remotefile.txt'
      c[:remote_file_name].should eq 'remotefile.txt'
    end
  end
end