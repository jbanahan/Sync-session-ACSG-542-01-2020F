require "spec_helper"

describe "FtpFileSupport" do
  class FtpSupportImpl 
    include OpenChain::FtpFileSupport

    def ftp_credentials
      return {:server=>'svr',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r', port: 123, protocol: 'proto'}
    end
  end

  subject { FtpSupportImpl.new }

  describe :ftp_file do
    before :each do
      @t = mock('tmpfile')
      @t.stub(:path).and_return('/x.badfile')
    end

    it "should ftp_file" do
      File.stub(:exists?).and_return true
      @t.should_receive(:unlink)
      FtpSender.should_receive(:send_file).with('svr','u','p',@t,{:folder=>'f',:remote_file_name=>'r', port: 123, protocol: 'proto'})
      subject.ftp_file @t
    end

    it "should take option_overrides" do
      File.stub(:exists?).and_return true
      FtpSender.should_receive(:send_file).with('otherserver','u','p',@t,{:folder=>'f',:remote_file_name=>'r', port:987, protocol: 'test'})
      @t.should_receive(:unlink)
      def subject.ftp_credentials
        return {:server=>'svr',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r', :protocol=>"test", port:987}
      end

      subject.ftp_file @t, {server:'otherserver'}
    end
    
    it 'should not unlink if false is passed' do
      File.stub(:exists?).and_return true
      @t.should_not_receive(:unlink)
      FtpSender.should_receive(:send_file).with('svr','u','p',@t,{:folder=>'f',:remote_file_name=>'r', port:123, protocol: 'proto'})
      subject.ftp_file @t, {keep_local:true}
    end
    
    it "should return false if file is nil" do
      File.stub(:exists?).and_return true
      FtpSender.should_not_receive(:send_file)
      subject.ftp_file(nil).should be_false
    end
    
    it "should return false if file does not exist" do
      FtpSender.should_not_receive(:send_file)
      subject.ftp_file(@t).should be_false
    end

    it "should allow for missing folder and remote file name values from ftp_credentials" do
      subject.should_receive(:ftp_credentials).and_return(:server=>'svr',:username=>'u',:password=>'p')
      File.stub(:exists?).and_return true
      @t.should_receive(:unlink)
      FtpSender.should_receive(:send_file).with('svr','u','p',@t,{})
      subject.ftp_file @t
    end
  end

  describe :ftp2_vandegrift_inc do

    it "should use the correct credentials for ftp2 server" do
      c = subject.ftp2_vandegrift_inc 'folder'
      c[:server].should eq 'ftp2.vandegriftinc.com'
      c[:username].should eq 'VFITRACK'
      c[:password].should eq 'RL2VFftp'
      c[:folder].should eq 'folder'
      c[:remote_file_name].should be_nil
    end

    it "should add remote filename when given" do
      c = subject.ftp2_vandegrift_inc 'folder', 'remotefile.txt'
      c[:remote_file_name].should eq 'remotefile.txt'
    end
  end

  describe "connect_vfitrack_net" do
    it "uses correct credentials" do
      c = subject.connect_vfitrack_net 'folder'
      expect(c[:server]).to eq 'connect.vfitrack.net'
      expect(c[:username]).to eq 'www-vfitrack-net'
      expect(c[:password]).to eq 'phU^`kN:@T27w.$'
      expect(c[:folder]).to eq 'folder'
      expect(c[:remote_file_name]).to be_nil
      expect(c[:protocol]).to eq "sftp"

      c = subject.connect_vfitrack_net 'folder', 'remotefile.txt'
      expect(c[:remote_file_name]).to eq "remotefile.txt"
    end
  end

  describe "fenixapp_vfitrack_net" do
    it "uses correct credentials" do
      expect(subject.fenixapp_vfitrack_net 'folder').to eq({
        server: "fenixapp.vfitrack.net",
        username: "vfitrack",
        password: "bJzgt1S##t",
        folder: "folder", 
        protocol: "sftp"
      })

      expect(subject.fenixapp_vfitrack_net('folder', 'filename.txt')[:remote_file_name]).to eq "filename.txt"
    end
  end

  describe "ecs_connect_vfitrack_net" do
    it "uses correct credentials" do
      expect(subject.ecs_connect_vfitrack_net 'folder').to eq({
        server: "connect.vfitrack.net",
        username: "ecs",
        password: "wzuomlo",
        folder: "folder", 
        protocol: "sftp",
        port: 2222
      })

      expect(subject.ecs_connect_vfitrack_net('folder', 'filename.txt')[:remote_file_name]).to eq "filename.txt"
    end
  end
end