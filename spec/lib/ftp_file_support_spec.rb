require "spec_helper"

describe "FtpFileSupport" do
  class FtpSupportImpl 
    include OpenChain::FtpFileSupport

    def ftp_credentials
      return {:server=>'svr',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r', port: 123, protocol: 'proto'}
    end
  end

  subject { FtpSupportImpl.new }

  describe "ftp_file" do
    let! (:tempfile) {
      Tempfile.new(["file", ".txt"])
    }

    after(:each) {
      tempfile.close! unless tempfile.closed?
    }

    it "should ftp_file" do
      expect(FtpSender).to receive(:send_file).with('svr','u','p',tempfile, subject.ftp_credentials)
      subject.ftp_file tempfile
      expect(tempfile.closed?).to be_truthy
      # Tempfile path is nil once it has been unlinked
      expect(tempfile.path).to be_nil
    end

    it "should take option_overrides" do
      def subject.ftp_credentials
        return {:server=>'svr',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r', :protocol=>"test", port:987}
      end

      expect(FtpSender).to receive(:send_file).with('otherserver','u','p',tempfile,{:server=>'otherserver',:username=>'u',:password=>'p',:folder=>'f',:remote_file_name=>'r', :protocol=>"test", port:987})
      subject.ftp_file tempfile, {server:'otherserver'}
    end
    
    it 'should not unlink if false is passed' do
      expect(File).to receive(:exists?).with(tempfile.to_path).and_return true
      expect(FtpSender).to receive(:send_file)
      subject.ftp_file tempfile, {keep_local:true}
      expect(tempfile.closed?).to be_falsey
    end
    
    it "should return false if file is nil" do
      expect(FtpSender).not_to receive(:send_file)
      expect(subject.ftp_file(nil)).to be_falsey
    end
    
    it "should return false if file does not exist" do
      expect(File).to receive(:exists?).with(tempfile.to_path).and_return false
      expect(FtpSender).not_to receive(:send_file)
      expect(subject.ftp_file tempfile).to be_falsey
    end

    it "should allow for missing folder and remote file name values from ftp_credentials" do
      expect(subject).to receive(:ftp_credentials).and_return(:server=>'svr',:username=>'u',:password=>'p')
      expect(FtpSender).to receive(:send_file).with('svr','u','p',tempfile,{:server=>'svr',:username=>'u',:password=>'p'})
      subject.ftp_file tempfile
    end

    it "allows including class to not implement ftp_credentials method" do
      s = class FakeFtper
        include OpenChain::FtpFileSupport
      end.new

      opts = {server: "server", username: "user", password: "pwd"}
      expect(FtpSender).to receive(:send_file).with('server','user','pwd',tempfile, opts)
      s.ftp_file tempfile, opts
    end

    it "yields the ftp session if a block is gvien" do
      session = FtpSession.new

      expect(FtpSender).to receive(:send_file).with('svr','u','p',tempfile, subject.ftp_credentials).and_return session
      expect{ |b| subject.ftp_file(tempfile, &b) }.to yield_with_args(session)
    end

    context "with a File object" do
      let (:file) {
        File.open("tmp/file.txt", "w+")
      }

      after(:each) {
        file.close unless file.closed?
        File.unlink("tmp/file.txt") rescue nil
      }

      it "deletes File objects after sent" do
        expect(FtpSender).to receive(:send_file).with('svr','u','p',file, subject.ftp_credentials)
        subject.ftp_file file
        expect(file.closed?).to be_truthy
        expect(File.exists? "tmp/file.txt").to be_falsey
      end
    end
  end

  describe "ftp_sync_file" do
    let (:session) { FtpSession.new }
    let (:file) { instance_double(File) }
    let (:overrides) { {:server=>'svr',:username=>'u',:password=>'p'} }

    it "uses ftp file and sets the yielded session into the sync record" do
      expect(subject).to receive(:ftp_file).with(file, overrides).and_yield session
      sync_record = SyncRecord.new
      subject.ftp_sync_file file, sync_record, overrides
      expect(sync_record.ftp_session).to eq session
    end

    it "handles multiple sync records" do
      expect(subject).to receive(:ftp_file).with(file, overrides).and_yield session
      sync_record_1 = SyncRecord.new
      sync_record_2 = SyncRecord.new
      subject.ftp_sync_file file, [sync_record_1, sync_record_2], overrides
      expect(sync_record_1.ftp_session).to eq session
      expect(sync_record_2.ftp_session).to eq session
    end
  end

  describe "ftp2_vandegrift_inc" do

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