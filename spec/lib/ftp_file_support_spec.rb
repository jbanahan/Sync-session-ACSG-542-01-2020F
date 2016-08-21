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
      @t = double('tmpfile')
      allow(@t).to receive(:path).and_return('/x.badfile')
    end

    it "should ftp_file" do
      allow(File).to receive(:exists?).and_return true
      expect(@t).to receive(:unlink)
      expect(FtpSender).to receive(:send_file).with('svr','u','p',@t, subject.ftp_credentials)
      subject.ftp_file @t
    end

    it "should take option_overrides" do
      allow(File).to receive(:exists?).and_return true
      
      def subject.ftp_credentials
        return {:server=>'svr',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r', :protocol=>"test", port:987}
      end

      expect(FtpSender).to receive(:send_file).with('otherserver','u','p',@t,{:server=>'otherserver',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r', :protocol=>"test", port:987})
      expect(@t).to receive(:unlink)

      subject.ftp_file @t, {server:'otherserver'}
    end
    
    it 'should not unlink if false is passed' do
      allow(File).to receive(:exists?).and_return true
      expect(@t).not_to receive(:unlink)
      expect(FtpSender).to receive(:send_file)
      subject.ftp_file @t, {keep_local:true}
    end
    
    it "should return false if file is nil" do
      allow(File).to receive(:exists?).and_return true
      expect(FtpSender).not_to receive(:send_file)
      expect(subject.ftp_file(nil)).to be_falsey
    end
    
    it "should return false if file does not exist" do
      expect(FtpSender).not_to receive(:send_file)
      expect(subject.ftp_file(@t)).to be_falsey
    end

    it "should allow for missing folder and remote file name values from ftp_credentials" do
      expect(subject).to receive(:ftp_credentials).and_return(:server=>'svr',:username=>'u',:password=>'p')
      allow(File).to receive(:exists?).and_return true
      expect(@t).to receive(:unlink)
      expect(FtpSender).to receive(:send_file).with('svr','u','p',@t,{:server=>'svr',:username=>'u',:password=>'p'})
      subject.ftp_file @t
    end

    it "allows including class to not implement ftp_credentials method" do
      s = class FakeFtper
        include OpenChain::FtpFileSupport
      end.new

      allow(File).to receive(:exists?).and_return true
      opts = {server: "server", username: "user", password: "pwd"}
      expect(FtpSender).to receive(:send_file).with('server','user','pwd',@t, opts)
      expect(@t).to receive(:unlink)
      s.ftp_file @t, opts
    end
  end

  describe :ftp2_vandegrift_inc do

    it "should use the correct credentials for ftp2 server" do
      c = subject.ftp2_vandegrift_inc 'folder'
      expect(c[:server]).to eq 'ftp2.vandegriftinc.com'
      expect(c[:username]).to eq 'VFITRACK'
      expect(c[:password]).to eq 'RL2VFftp'
      expect(c[:folder]).to eq 'folder'
      expect(c[:remote_file_name]).to be_nil
    end

    it "should add remote filename when given" do
      c = subject.ftp2_vandegrift_inc 'folder', 'remotefile.txt'
      expect(c[:remote_file_name]).to eq 'remotefile.txt'
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