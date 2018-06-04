describe IntegrationParserSupport do

  # TODO last_file_secure_url not unit tested

  describe "has_last_file?" do
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
      before :each do
        @tempfile = Tempfile.new ['file', '.txt']
        @tempfile << "File Contents"
        @tempfile.flush
        ms = stub_master_setup
        allow(ms).to receive(:send_test_files_to_instance).and_return "test_server"
      end

      after :each do
        @tempfile.close! unless @tempfile.closed?
      end

      it "sends file to test" do
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("this_bucket", "2018-05/04/www.vfitrack.net/_kewill_entry/long_file_name.json").and_yield @tempfile
        expect_any_instance_of(subject.class).to receive(:ftp_file).with(@tempfile, {server: 'connect.vfitrack.net', username: 'ecs', password: 'wzuomlo', folder: "test_server/_kewill_entry", protocol: 'sftp', port: 2222, remote_file_name: "long_file_name.json"})
        subject.class.send_integration_file_to_test "this_bucket", "2018-05/04/www.vfitrack.net/_kewill_entry/long_file_name.json"
      end
    end

    # Segregated so we don't waste effort building a Tempfile for these.
    describe "failure" do
      it "sends nothing when bucket is missing" do
        expect(OpenChain::S3).to_not receive(:download_to_tempfile)
        expect_any_instance_of(subject.class).to_not receive(:ftp_file)
        subject.class.send_integration_file_to_test nil, "2018-05/04/www.vfitrack.net/_kewill_entry/long_file_name.json"
      end

      it "sends nothing when path is missing" do
        expect(OpenChain::S3).to_not receive(:download_to_tempfile)
        expect_any_instance_of(subject.class).to_not receive(:ftp_file)
        subject.class.send_integration_file_to_test "this_bucket", nil
      end
    end
  end

end