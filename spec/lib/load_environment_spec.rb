describe OpenChain::LoadEnvironment do

  subject { described_class }

  describe "load" do
    it "loads dot env files" do
      expect(Dotenv::Railtie).to receive(:load)
      subject.load
    end
  end

  describe "application_load" do
    it "loads memcache" do
      expect(CacheWrapper).to receive(:instance)
      subject.application_load
    end

    it "does not load memcache if WITHOUT_CONFIG_FILES environment variable is set" do
      expect(CacheWrapper).not_to receive(:instance)
      expect(ENV).to receive(:[]).with("WITHOUT_CONFIG_FILES").and_return "true"

      subject.application_load
    end
  end

  describe "download_config_files" do

    context "with ENV vars" do

      let (:config_data) { "config file data" }
      let (:file) { StringIO.new }

      it "downloads all config files from s3" do
        expect(MasterSetup).to receive(:env).with("CONFIGURATION_BUCKET").and_return "bucket"
        expect(MasterSetup).to receive(:env).with("CONFIGURATION_NAMESPACE").and_return "namespace"

        expect(OpenChain::S3).to receive(:each_file_in_bucket).with("bucket", prefix: "namespace/").and_yield "namespace/tmp/file.txt"
        expect(OpenChain::S3).to receive(:get_data) do |bucket, path, io|
          expect(bucket).to eq "bucket"
          expect(path).to eq "namespace/tmp/file.txt"
          io << config_data
          nil
        end
        expect(File).to receive(:open).with(MasterSetup.instance_directory.join("tmp/file.txt"), "w").and_yield file

        subject.download_config_files
        file.rewind
        expect(file.read).to eq "config file data"
      end
    end

    context "with master secret vars" do
      let (:secrets) do
        {
          "host" => "hostname.domain.com",
          "configuration_bucket" => "bucket"
        }
      end

      it "downloads all config files from s3" do
        allow(MasterSetup).to receive(:secrets).and_return secrets
        expect(OpenChain::S3).to receive(:each_file_in_bucket).with("bucket", prefix: "hostname/").and_yield "hostname/tmp/file.txt"
        expect(subject).to receive(:download_file).with(MasterSetup.instance_directory, "hostname", "bucket", "hostname/tmp/file.txt", false)

        subject.download_config_files
      end

      it "uses instance identifier if no host is configured in secrets" do
        secrets.delete "host"
        allow(MasterSetup).to receive(:instance_directory).and_return Pathname.new("/path/to/identifier")
        allow(MasterSetup).to receive(:secrets).and_return secrets
        expect(OpenChain::S3).to receive(:each_file_in_bucket).with("bucket", prefix: "identifier/").and_yield "identifier/tmp/file.txt"
        expect(subject).to receive(:download_file).with(MasterSetup.instance_directory, "identifier", "bucket", "identifier/tmp/file.txt", false)

        subject.download_config_files
      end

      it "raises an error if no bucket is configured" do
        allow(MasterSetup).to receive(:secrets).and_return({})
        expect { subject.download_config_files }.to raise_error "No configuration bucket found. Set a configuration_bucket key in secrets.yml or set the CONFIGURATION_BUCKET env var." # rubocop:disable Layout/LineLength
      end
    end

    describe "configuration_bucket" do
      it "uses ENV var if configured" do
        allow(MasterSetup).to receive(:env).with("CONFIGURATION_BUCKET").and_return("env_bucket")
        expect(subject.configuration_bucket).to eq "env_bucket"
      end

      it "uses secrets configuration_bucket" do
        allow(MasterSetup).to receive(:env).and_return(nil)
        allow(MasterSetup).to receive(:secrets).and_return({"configuration_bucket" => "secret_bucket"})
        expect(subject.configuration_bucket).to eq "secret_bucket"
      end
    end

    describe "configuration_namespace" do

      it "uses ENV var if configured" do
        allow(MasterSetup).to receive(:env).with("CONFIGURATION_NAMESPACE").and_return("env_namespace")
        expect(subject.configuration_namespace).to eq "env_namespace"
      end

      it "uses secrets namespace if configured" do
        allow(MasterSetup).to receive(:env).with("CONFIGURATION_NAMESPACE").and_return(nil)
        allow(MasterSetup).to receive(:secrets).and_return({"configuration_namespace" => "secrets_namespace", "host" => "namespace.domain.com"})
        expect(subject.configuration_namespace).to eq "secrets_namespace"
      end

      it "uses secrets host if configured" do
        allow(MasterSetup).to receive(:env).with("CONFIGURATION_NAMESPACE").and_return(nil)
        allow(MasterSetup).to receive(:secrets).and_return({"host" => "namespace.domain.com"})
        expect(subject.configuration_namespace).to eq "namespace"
      end

      it "uses instance directory name if nothing else is present" do
        allow(MasterSetup).to receive(:env).with("CONFIGURATION_NAMESPACE").and_return(nil)
        allow(MasterSetup).to receive(:secrets).and_return({})
        expect(MasterSetup).to receive(:instance_directory).and_return Pathname.new("/path/to/instance")
        expect(subject.configuration_namespace).to eq "instance"
      end
    end
  end

  describe "YamlEscapePatch" do

    it "handles strings that don't need to be escaped" do
      expect("test".escape_yaml).to eq "test"
    end

    it "escapes YAML string" do
      expect("&test".escape_yaml).to eq '"&test"'
    end

    it "handles blank values" do
      v = "  "
      # This proves that if we pass a blank string we get the same object back
      expect(v.escape_yaml).to be v
    end

    it "handles nil values" do
      expect(nil.escape_yaml).to be_nil
    end
  end

  describe "running_from_console?" do

    it "returns true if Console constant define in Rails namespace" do
      expect(Rails).to receive(:const_defined?).with("Console").and_return true
      expect(subject.running_from_console?).to eq true
    end

    it "returns true if system was invoked from rake" do
      expect(File).to receive(:basename).with($PROGRAM_NAME).and_return "rake"
      expect(subject.running_from_console?).to eq true
    end

    it "returns false if Console not defined and rake not utilized" do
      expect(File).to receive(:basename).with($PROGRAM_NAME).and_return "rails"
      expect(Rails).to receive(:const_defined?).with("Console").and_return false
      expect(subject.running_from_console?).to eq false
    end
  end
end