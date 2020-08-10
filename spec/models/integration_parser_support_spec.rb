describe IntegrationParserSupport do

  describe "last_file_secure_url" do
    context "generates URL when bucket and path are present" do
      let(:c) { make_integration_parser_support_class "this_bucket", "this_path" }

      it "uses default expiration" do
        expect(OpenChain::S3).to receive(:url_for).with("this_bucket", "this_path", 60.seconds).and_return "Yep"
        expect(c.last_file_secure_url).to eq "Yep"
      end

      it "uses specified expiration" do
        expect(OpenChain::S3).to receive(:url_for).with("this_bucket", "this_path", 33.seconds).and_return "Yep"
        expect(c.last_file_secure_url(33.seconds)).to eq "Yep"
      end
    end

    it "returns nil when there's no bucket" do
      expect(OpenChain::S3).not_to receive(:url_for)
      expect(make_integration_parser_support_class(nil, "this_path").last_file_secure_url).to be_nil
    end

    it "returns nil when there's no path" do
      expect(OpenChain::S3).not_to receive(:url_for)
      expect(make_integration_parser_support_class("this_bucket", nil).last_file_secure_url).to be_nil
    end
  end

  def make_integration_parser_support_class bucket, path
    Class.new do
      include IntegrationParserSupport

      attr_reader :last_file_bucket, :last_file_path

      def initialize(last_file_bucket, last_file_path)
        @last_file_bucket = last_file_bucket
        @last_file_path = last_file_path
      end
    end.new(bucket, path)
  end

  describe "has_last_file?" do
    it "has bucket and path" do
      expect(make_integration_parser_support_class("this_bucket", "this_path").has_last_file?).to eq true
    end

    it "is missing bucket" do
      expect(make_integration_parser_support_class(nil, "this_path").has_last_file?).to eq false
      expect(make_integration_parser_support_class("", "this_path").has_last_file?).to eq false
      expect(make_integration_parser_support_class("  ", "this_path").has_last_file?).to eq false
    end

    it "is missing path" do
      expect(make_integration_parser_support_class("this_bucket", nil).has_last_file?).to eq false
      expect(make_integration_parser_support_class("this_bucket", "").has_last_file?).to eq false
      expect(make_integration_parser_support_class("this_bucket", "  ").has_last_file?).to eq false
    end
  end

  describe "send_integration_file_to_test" do
    let (:subject) { Class.new { include IntegrationParserSupport }.new }

    describe "success" do
      let(:tempfile) do
        t = Tempfile.new ['file', '.txt']
        t << "File Contents"
        t.flush
        t
      end

      before do
        ms = stub_master_setup
        allow(ms).to receive(:send_test_files_to_instance).and_return "test_server"
      end

      after do
        tempfile.close! unless tempfile.closed?
      end

      it "sends file to test" do
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("this_bucket", "2018-05/04/www.vfitrack.net/_kewill_entry/long_file_name.json").and_yield tempfile
        expect_any_instance_of(subject.class).to receive(:ftp_file)
          .with(tempfile, {server: 'connect.vfitrack.net', username: 'ecs', password: 'wzuomlo',
                           folder: "test_server/_kewill_entry", protocol: 'sftp', port: 2222, remote_file_name: "long_file_name.json"})
        subject.class.send_integration_file_to_test "this_bucket", "2018-05/04/www.vfitrack.net/_kewill_entry/long_file_name.json"
      end
    end

    # Segregated so we don't waste effort building a Tempfile for these.
    describe "failure" do
      it "sends nothing when bucket is missing" do
        expect(OpenChain::S3).not_to receive(:download_to_tempfile)
        expect_any_instance_of(subject.class).not_to receive(:ftp_file)
        subject.class.send_integration_file_to_test nil, "2018-05/04/www.vfitrack.net/_kewill_entry/long_file_name.json"
      end

      it "sends nothing when path is missing" do
        expect(OpenChain::S3).not_to receive(:download_to_tempfile)
        expect_any_instance_of(subject.class).not_to receive(:ftp_file)
        subject.class.send_integration_file_to_test "this_bucket", nil
      end
    end
  end

  describe "can_view_integration_link?" do

    let (:object) { Entry.new last_file_bucket: "bucket", last_file_path: "file.txt" }

    it "allows sys admins to view" do
      user = User.new
      user.sys_admin = true
      expect(object.can_view_integration_link?(user)).to eq true
    end

    it "allows admins to view if custom feature enabled" do
      user = User.new
      user.admin = true
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("Admins View Integration Files").and_return true
      expect(object.can_view_integration_link?(user)).to eq true
    end

    it "does not allow admins to view if custom feature is not enabled" do
      user = User.new
      user.admin = true
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("Admins View Integration Files").and_return false
      expect(object.can_view_integration_link?(user)).to eq false
    end

    it "does not allow standard accounts to view" do
      user = User.new
      expect(object.can_view_integration_link?(user)).to eq false
    end

    it "does not allow anyone to view if there is no last file" do
      expect(object).to receive(:has_last_file?).and_return false
      user = User.new
      user.sys_admin = true
      expect(object.can_view_integration_link?(user)).to eq false
    end
  end
end