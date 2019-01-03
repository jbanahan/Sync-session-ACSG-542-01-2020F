describe OpenChain::FtpSiteMonitor do

  let (:valid_opts) {
    {protocol: "sftp", hostname: "ftpserver", username: "user", password: "password", directory: "dir", 
      email_to: ["me@there.com"], max_age_minutes: 60}
     
  }

  describe "run_schedulable" do
    subject { described_class }
    it "runs using passed opts" do
      expect_any_instance_of(subject).to receive(:run).with valid_opts, 60, ["me@there.com"], nil, nil
      subject.run_schedulable valid_opts
    end

    context "with validations" do
      after :each do
        expect { subject.run_schedulable }.to raise_error ArgumentError
      end

      ["hostname", "username", "password", "directory", "max_age_minutes", "email_to"].each do |k|
        it "validates that #{k} is required" do
          valid_opts.delete k.to_sym
        end
      end
    end

    it "looks up mailing list and sets into email_to" do 
      list = MailingList.create! company_id: Factory(:company).id, user_id: Factory(:user).id, system_code: "list", name: "list", email_addresses: "me@there.com"
      valid_opts[:mailing_list] = "list"
      expect_any_instance_of(subject).to receive(:run).with anything, anything, instance_of(MailingList), nil, nil
      subject.run_schedulable valid_opts
    end

    it "errors if MailingList isn't found" do
      valid_opts[:mailing_list] = "list"
      expect { subject.run_schedulable valid_opts}.to raise_error "No Mailing List found with system code 'list'."
    end

    it "uses subject and additional message options" do
      valid_opts[:email_subject] = "Subject"
      valid_opts[:additional_email_message] = "Message"
      expect_any_instance_of(subject).to receive(:run).with anything, anything, anything, "Subject", "Message"
      subject.run_schedulable valid_opts
    end
  end

  describe "run" do

    let (:ftp_file) {
      f = instance_double(FtpSender::FtpFile)
      allow(f).to receive(:mtime).and_return Time.zone.now - 60.minutes
      f
    }

    let (:ftp_client) {
      c = instance_double(FtpSender::FtpClient)
    }

    it "ftps and reports old files" do
      expect(ftp_client).to receive(:connect).with("ftpserver", "user", "password", "", {}).and_yield ftp_client
      expect(ftp_client).to receive(:chdir).with("dir")
      expect(ftp_client).to receive(:list_files).and_return [ftp_file]
      expect(subject).to receive(:ftp_client).with("sftp").and_return ftp_client

      subject.run valid_opts, 10, "me@there.com", nil, nil

      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Sftp monitor failure for ftpserver / dir"
    end

    it "doesn't report if no old files" do
      expect(ftp_client).to receive(:connect).with("ftpserver", "user", "password", "", {}).and_yield ftp_client
      expect(ftp_client).to receive(:chdir).with("dir")
      expect(ftp_client).to receive(:list_files).and_return [ftp_file]
      expect(subject).to receive(:ftp_client).with("sftp").and_return ftp_client

      subject.run valid_opts, 65, "me@there.com", nil, nil

      m = ActionMailer::Base.deliveries.first
      expect(m).to be_nil
    end

    it "uses given subject and adds additional message" do
      expect(ftp_client).to receive(:connect).with("ftpserver", "user", "password", "", {}).and_yield ftp_client
      expect(ftp_client).to receive(:chdir).with("dir")
      expect(ftp_client).to receive(:list_files).and_return [ftp_file]
      expect(subject).to receive(:ftp_client).with("sftp").and_return ftp_client

      subject.run valid_opts, 10, "me@there.com", "Different Subject", "Additional Message"

      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Different Subject"
      expect(m.body).to include "Additional Message"
    end
  end

  describe "ftp_client" do
    it "returns FtpClient for ftp protocol" do
      expect(subject.ftp_client "ftp").to be_an_instance_of(FtpSender::FtpClient)
    end

    it "returns SftpClient for anything else" do
      expect(subject.ftp_client "something random").to be_an_instance_of(FtpSender::SftpClient)
    end
  end
end