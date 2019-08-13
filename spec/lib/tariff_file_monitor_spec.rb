describe OpenChain::TariffFileMonitor do
  RSpec::Matchers.define :tempfile_matching_name do |name|
    match { |actual| actual.is_a?(Tempfile) && actual.original_filename == name }
  end

  describe "run" do
    it "downloads and distributes tariff files" do
      inst_1_au = TariffFileUploadInstance.new vfi_track_system_code:"inst_1"
      inst_2_au = TariffFileUploadInstance.new vfi_track_system_code:"inst_2"
      def_au = TariffFileUploadDefinition.create! country_code:"AU", filename_regex:"AU_SIMPLE_.+\.ZIP", tariff_file_upload_instances: [inst_1_au, inst_2_au]
      inst_1_c9 = TariffFileUploadInstance.new vfi_track_system_code:"inst_1"
      def_c9 = TariffFileUploadDefinition.create! country_code:"C9", filename_regex:"C9_SIMPLE_.+\.ZIP", country_iso_alias:"CN", tariff_file_upload_instances: [inst_1_c9]
      inst_2_cn = TariffFileUploadInstance.new vfi_track_system_code:"inst_2"
      def_cn = TariffFileUploadDefinition.create! country_code:"CN", filename_regex:"CN_SIMPLE_.+\.ZIP", tariff_file_upload_instances: [inst_2_cn]
      inst_1_eu = TariffFileUploadInstance.new vfi_track_system_code:"inst_1", country_iso_alias:"IT"
      inst_2_eu = TariffFileUploadInstance.new vfi_track_system_code:"inst_2", country_iso_alias:"NL"
      def_eu = TariffFileUploadDefinition.create! country_code:"EU", filename_regex:"EU_SIMPLE_.+\.ZIP", tariff_file_upload_instances: [inst_1_eu, inst_2_eu]

      key = KeyJsonItem.polling_job('OpenChain::TariffFileMonitor').create! json_data: "{\"last_run\":\"2017-07-06 05:55\"}"

      ftp_client = double("ftp_client")
      expect(FtpSender::SftpClient).to receive(:new).and_return(ftp_client)
      ftp_connection = double("ftp_connection")
      expect(ftp_client).to receive(:connect).with("testftpserver.fake-testing.com", "artie_fufkin", "pwd555", "", {port:"5150"}).and_yield ftp_connection
      expect(ftp_connection).to receive(:chdir).with("base_dir")
      time_zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      expect(ftp_connection).to receive(:list_files).with(include_only_files:false).and_return [
              FtpSender::FtpFile.new("Australia", 0, time_zone.local(2017,7,7), "directory"),
              # This file should be ignored.  We're looking for folders only.
              FtpSender::FtpFile.new("errant_zip.zip", 0, time_zone.local(2017,7,8), "file"),
              FtpSender::FtpFile.new("China", 0, time_zone.local(2017,7,8), "directory"),
              FtpSender::FtpFile.new("European Union", 0, time_zone.local(2017,7,9), "directory"),
              # This directory should be ignored.  It hasn't been updated since the last pickup.
              FtpSender::FtpFile.new("Argentina", 0, time_zone.local(2017,7,5), "directory")]

      expect(ftp_connection).to receive(:chdir).with("base_dir/Australia")
      expect(ftp_connection).to receive(:list_files).and_return [
              FtpSender::FtpFile.new("AU_SIMPLE_20170707.ZIP", 0, time_zone.local(2017,7,7), "file"),
              # This changes file should be ignored without error.  We're specifically filtering out change files.
              FtpSender::FtpFile.new("AU_20170707_changes.zip", 0, time_zone.local(2017,7,7), "file"),
              # This non-zip file should be ignored without error.  We're specifically looking for only zips.
              FtpSender::FtpFile.new("AU_SIMPLE_20170709.txt", 0, time_zone.local(2017,7,9), "file"),
              # This one should be also ignored without error.  It's older than the last pickup.
              FtpSender::FtpFile.new("AU_SIMPLE_20170507.ZIP", 0, time_zone.local(2017,5,7), "file")]
      expect(ftp_connection).to receive(:get_binary_file).with("AU_SIMPLE_20170707.ZIP", /tariff_upload.+\.zip/)

      expect(ftp_connection).to receive(:chdir).with("base_dir/China")
      expect(ftp_connection).to receive(:list_files).and_return [
              FtpSender::FtpFile.new("C9_SIMPLE_20170708.ZIP", 0, time_zone.local(2017,7,8), "file"),
              FtpSender::FtpFile.new("CN_SIMPLE_20170707.ZIP", 0, time_zone.local(2017,7,7), "file"),
              FtpSender::FtpFile.new("CN_20170708_changes.zip", 0, time_zone.local(2017,7,8), "file")]
      expect(ftp_connection).to receive(:get_binary_file).with("C9_SIMPLE_20170708.ZIP", /tariff_upload.+\.zip/)
      expect(ftp_connection).to receive(:get_binary_file).with("CN_SIMPLE_20170707.ZIP", /tariff_upload.+\.zip/)

      expect(ftp_connection).to receive(:chdir).with("base_dir/European Union")
      expect(ftp_connection).to receive(:list_files).and_return [
              FtpSender::FtpFile.new("EU_SIMPLE_20170708.ZIP", 0, time_zone.local(2017,7,8), "file")]
      expect(ftp_connection).to receive(:get_binary_file).with("EU_SIMPLE_20170708.ZIP", /tariff_upload.+\.zip/)

      expect(subject).to receive(:ftp_file).with(tempfile_matching_name("AU_SIMPLE_20170707.ZIP"), subject.chainroot_connect_vfitrack_net("inst_1/tariff_file"))
      expect(subject).to receive(:ftp_file).with(tempfile_matching_name("CN_C9_SIMPLE_20170708.ZIP"), subject.chainroot_connect_vfitrack_net("inst_1/tariff_file"))
      expect(subject).to receive(:ftp_file).with(tempfile_matching_name("IT_EU_SIMPLE_20170708.ZIP"), subject.chainroot_connect_vfitrack_net("inst_1/tariff_file"))
      expect(subject).to receive(:ftp_file).with(tempfile_matching_name("AU_SIMPLE_20170707.ZIP"), subject.chainroot_connect_vfitrack_net("inst_2/tariff_file"))
      expect(subject).to receive(:ftp_file).with(tempfile_matching_name("CN_SIMPLE_20170707.ZIP"), subject.chainroot_connect_vfitrack_net("inst_2/tariff_file"))
      expect(subject).to receive(:ftp_file).with(tempfile_matching_name("NL_EU_SIMPLE_20170708.ZIP"), subject.chainroot_connect_vfitrack_net("inst_2/tariff_file"))

      expect(OpenChain::S3).to receive(:upload_file).with(OpenChain::S3.bucket_name, "production/TariffStore/AU_SIMPLE_20170707.ZIP", tempfile_matching_name("AU_SIMPLE_20170707.ZIP"))
      expect(OpenChain::S3).to receive(:upload_file).with(OpenChain::S3.bucket_name, "production/TariffStore/CN_C9_SIMPLE_20170708.ZIP", tempfile_matching_name("CN_C9_SIMPLE_20170708.ZIP"))
      expect(OpenChain::S3).to receive(:upload_file).with(OpenChain::S3.bucket_name, "production/TariffStore/CN_SIMPLE_20170707.ZIP", tempfile_matching_name("CN_SIMPLE_20170707.ZIP"))
      expect(OpenChain::S3).to receive(:upload_file).with(OpenChain::S3.bucket_name, "production/TariffStore/EU_SIMPLE_20170708.ZIP", tempfile_matching_name("EU_SIMPLE_20170708.ZIP"))

      current = time_zone.local(2017,10,31,3,3,33)
      Timecop.freeze(current) do
        subject.run({ protocol:"SFTP", hostname:"testftpserver.fake-testing.com", port:"5150", username:"artie_fufkin", password:"pwd555", directory:"base_dir", email_to:["a@b.com", "c@d.com"] })
      end

      expect(inst_1_au.tariff_file_upload_receipts[0].filename).to eq "AU_SIMPLE_20170707.ZIP"
      expect(inst_1_c9.tariff_file_upload_receipts[0].filename).to eq "C9_SIMPLE_20170708.ZIP"
      expect(inst_1_eu.tariff_file_upload_receipts[0].filename).to eq "EU_SIMPLE_20170708.ZIP"
      expect(inst_2_au.tariff_file_upload_receipts[0].filename).to eq "AU_SIMPLE_20170707.ZIP"
      expect(inst_2_cn.tariff_file_upload_receipts[0].filename).to eq "CN_SIMPLE_20170707.ZIP"
      expect(inst_2_eu.tariff_file_upload_receipts[0].filename).to eq "EU_SIMPLE_20170708.ZIP"

      key.reload
      expect(key.json_data).to eq("{\"last_run\":\"2017-10-31T07:03:33Z\"}")

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries[0]
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq 'Tariff File Monitor Update'
      expect(mail.body).to include ERB::Util.html_escape("4 files were processed from the pickup directory.</p><ol><li>AU_SIMPLE_20170707.ZIP</li><li>C9_SIMPLE_20170708.ZIP</li><li>CN_SIMPLE_20170707.ZIP</li><li>EU_SIMPLE_20170708.ZIP</li></ol>".html_safe)
      expect(mail.attachments.length).to eq 0
    end

    it "errors on unknown country and regex mismatches" do
      inst_au = TariffFileUploadInstance.new vfi_track_system_code:"inst_1"
      def_au = TariffFileUploadDefinition.create! country_code:"AU", filename_regex:"AU_SIMPLE_.+\.ZIP", tariff_file_upload_instances: [inst_au]

      key = KeyJsonItem.polling_job('OpenChain::TariffFileMonitor').create! json_data: "{\"last_run\":\"2017-07-06 05:55\"}"

      ftp_client = double("ftp_client")
      expect(FtpSender::FtpClient).to receive(:new).and_return(ftp_client)
      ftp_connection = double("ftp_connection")
      expect(ftp_client).to receive(:connect).with("testftpserver.fake-testing.com", "artie_fufkin", "pwd555", "", {port:"5150"}).and_yield ftp_connection
      expect(ftp_connection).to receive(:chdir).with("base_dir")
      time_zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      expect(ftp_connection).to receive(:list_files).with(include_only_files:false).and_return [
              FtpSender::FtpFile.new("Australia", 0, time_zone.local(2017,7,7), "directory"),
              FtpSender::FtpFile.new("Wakanda", 0, time_zone.local(2017,7,8), "directory")]

      expect(ftp_connection).to receive(:chdir).with("base_dir/Australia")
      expect(ftp_connection).to receive(:list_files).and_return [
              FtpSender::FtpFile.new("AU_SIMPLE_20170707.ZIP", 0, time_zone.local(2017,7,7), "file"),
              FtpSender::FtpFile.new("AU_COMPLICATED_20170707.ZIP", 0, time_zone.local(2017,7,7), "file")]
      expect(ftp_connection).to receive(:get_binary_file).with("AU_SIMPLE_20170707.ZIP", /tariff_upload.+\.zip/)
      expect(ftp_connection).to receive(:get_binary_file).with("AU_COMPLICATED_20170707.ZIP", /tariff_upload.+\.zip/)

      expect(ftp_connection).to receive(:chdir).with("base_dir/Wakanda")
      expect(ftp_connection).to receive(:list_files).and_return [
              FtpSender::FtpFile.new("WA_SIMPLE_20170708.ZIP", 0, time_zone.local(2017,7,8), "file")]
      expect(ftp_connection).to receive(:get_binary_file).with("WA_SIMPLE_20170708.ZIP", /tariff_upload.+\.zip/)

      expect(subject).to receive(:ftp_file).with(tempfile_matching_name("AU_SIMPLE_20170707.ZIP"), subject.chainroot_connect_vfitrack_net("inst_1/tariff_file"))

      expect(OpenChain::S3).to receive(:upload_file).with(OpenChain::S3.bucket_name, "production/TariffStore/AU_SIMPLE_20170707.ZIP", tempfile_matching_name("AU_SIMPLE_20170707.ZIP"))

      current = time_zone.local(2017,10,31,3,3,33)
      Timecop.freeze(current) do
        subject.run({ protocol:"FTP", hostname:"testftpserver.fake-testing.com", port:"5150", username:"artie_fufkin", password:"pwd555", directory:"base_dir", email_to:["a@b.com", "c@d.com"] })
      end

      expect(inst_au.tariff_file_upload_receipts[0].filename).to eq "AU_SIMPLE_20170707.ZIP"

      expect(ActionMailer::Base.deliveries.length).to eq 2
      mail = ActionMailer::Base.deliveries[0]
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq 'Tariff File Monitor Errors'
      expect(mail.body).to include ERB::Util.html_escape("Errors were encountered while processing tariff files.</p><ol><li>Tariff file received for country code 'AU' did not match the file naming standard: AU_COMPLICATED_20170707.ZIP.</li><li>Tariff file received for country code 'WA': WA_SIMPLE_20170708.ZIP.  Nothing has been set up for this country.</li></ol>".html_safe)
      expect(mail.attachments.length).to eq 0

      mail = ActionMailer::Base.deliveries[1]
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq 'Tariff File Monitor Update'
      expect(mail.body).to include ERB::Util.html_escape("1 file was processed from the pickup directory.</p><ol><li>AU_SIMPLE_20170707.ZIP</li></ol>".html_safe)
      expect(mail.attachments.length).to eq 0
    end

    it "sends notifications based on mailing list" do
      inst_au = TariffFileUploadInstance.new vfi_track_system_code:"inst_1"
      def_au = TariffFileUploadDefinition.create! country_code:"AU", filename_regex:"AU_SIMPLE_.+\.ZIP", tariff_file_upload_instances: [inst_au]

      key = KeyJsonItem.polling_job('OpenChain::TariffFileMonitor').create! json_data: "{\"last_run\":\"2017-07-06 05:55\"}"

      Factory(:mailing_list, system_code:"IGNORE ME", email_addresses: "a@b.com,c@d.com")

      ftp_client = double("ftp_client")
      expect(FtpSender::FtpClient).to receive(:new).and_return(ftp_client)
      ftp_connection = double("ftp_connection")
      expect(ftp_client).to receive(:connect).with("testftpserver.fake-testing.com", "artie_fufkin", "pwd555", "", {}).and_yield ftp_connection
      expect(ftp_connection).to receive(:chdir).with("base_dir")
      time_zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      expect(ftp_connection).to receive(:list_files).with(include_only_files:false).and_return [FtpSender::FtpFile.new("Australia", 0, time_zone.local(2017,7,7), "directory")]

      expect(ftp_connection).to receive(:chdir).with("base_dir/Australia")
      expect(ftp_connection).to receive(:list_files).and_return [FtpSender::FtpFile.new("AU_SIMPLE_20170707.ZIP", 0, time_zone.local(2017,7,7), "file")]
      expect(ftp_connection).to receive(:get_binary_file).with("AU_SIMPLE_20170707.ZIP", /tariff_upload.+\.zip/)

      expect(subject).to receive(:ftp_file).with(tempfile_matching_name("AU_SIMPLE_20170707.ZIP"), subject.chainroot_connect_vfitrack_net("inst_1/tariff_file"))

      expect(OpenChain::S3).to receive(:upload_file).with(OpenChain::S3.bucket_name, "production/TariffStore/AU_SIMPLE_20170707.ZIP", tempfile_matching_name("AU_SIMPLE_20170707.ZIP"))

      current = time_zone.local(2017,10,31,3,3,33)
      Timecop.freeze(current) do
        subject.run({ protocol:"FTP", hostname:"testftpserver.fake-testing.com", username:"artie_fufkin", password:"pwd555", directory:"base_dir", mailing_list:"IGNORE ME" })
      end

      expect(inst_au.tariff_file_upload_receipts[0].filename).to eq "AU_SIMPLE_20170707.ZIP"

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries[0]
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq 'Tariff File Monitor Update'
      expect(mail.body).to include ERB::Util.html_escape("1 file was processed from the pickup directory.</p><ol><li>AU_SIMPLE_20170707.ZIP</li></ol>".html_safe)
      expect(mail.attachments.length).to eq 0
    end

    describe "argument errors" do
      it "errors on missing protocol" do
        expect { subject.run({ hostname:"testftpserver.fake-testing.com", port:"5150", username:"artie_fufkin", password:"pwd555", directory:"base_dir", email_to:["a@b.com", "c@d.com"] }) }.to raise_error(ArgumentError, "'protocol', 'hostname', 'username', 'password', and 'directory' are all required.")
      end

      it "errors on missing hostname" do
        expect { subject.run({ protocol:"FTP", port:"5150", username:"artie_fufkin", password:"pwd555", directory:"base_dir", email_to:["a@b.com", "c@d.com"] }) }.to raise_error(ArgumentError, "'protocol', 'hostname', 'username', 'password', and 'directory' are all required.")
      end

      it "errors on missing username" do
        expect { subject.run({ protocol:"FTP", hostname:"testftpserver.fake-testing.com", port:"5150", password:"pwd555", directory:"base_dir", email_to:["a@b.com", "c@d.com"] }) }.to raise_error(ArgumentError, "'protocol', 'hostname', 'username', 'password', and 'directory' are all required.")
      end

      it "errors on missing password" do
        expect { subject.run({ protocol:"FTP", hostname:"testftpserver.fake-testing.com", port:"5150", username:"artie_fufkin", directory:"base_dir", email_to:["a@b.com", "c@d.com"] }) }.to raise_error(ArgumentError, "'protocol', 'hostname', 'username', 'password', and 'directory' are all required.")
      end

      it "errors on missing directory" do
        expect { subject.run({ protocol:"FTP", hostname:"testftpserver.fake-testing.com", port:"5150", username:"artie_fufkin", password:"pwd555", email_to:["a@b.com", "c@d.com"] }) }.to raise_error(ArgumentError, "'protocol', 'hostname', 'username', 'password', and 'directory' are all required.")
      end

      it "errors on missing email" do
        expect { subject.run({ protocol:"FTP", hostname:"testftpserver.fake-testing.com", port:"5150", username:"artie_fufkin", password:"pwd555", directory:"base_dir" }) }.to raise_error(ArgumentError, "One of 'email_to' or 'mailing_list' is required.")
      end

      it "errors on bad mailing list" do
        expect { subject.run({ protocol:"FTP", hostname:"testftpserver.fake-testing.com", port:"5150", username:"artie_fufkin", password:"pwd555", directory:"base_dir", mailing_list:"FAKE LIST" }) }.to raise_error(ArgumentError, "No Mailing List found with system code 'FAKE LIST'.")
      end
    end

  end

  describe "run_schedulable" do
    it "runs a scheduled version of the monitor" do
      expect_any_instance_of(described_class).to receive(:run).with({opt_1:"A", opt_2:"B"})

      described_class.run_schedulable({opt_1:"A", opt_2:"B"})
    end
  end
end