describe OpenChain::AntiVirus::ClambyAntiVirus do

  subject { described_class }

  describe "safe?" do
    let (:file_path) { "/path/to/file.txt" }
    let (:file) {
      File.open(__FILE__, "r")
    }

    after :each do 
      file.close unless file.closed?
    end

    it "uses Clamby to scan the file path" do
      expect(File).to receive(:file?).with(file_path).and_return true
      expect(Clamby).to receive(:safe?).with(file_path).and_return true
      expect(subject.safe? file_path).to eq true
    end

    it "errors if file doesn't exist" do
      expect { subject.safe? "/fake/file.txt" }.to raise_error Errno::ENOENT, "No such file or directory - /fake/file.txt"
    end
  end

  describe "registered" do
    it "configures Clamby" do
      # I just want to make sure any anti-virus adjustments are intended...hence the test
      expect(Clamby).to receive(:configure).with({
        check: true,
        daemonize: true,
        fdpass: true,
        stream: true,
        output_level: 'off'
      })
      expect(MasterSetup).to receive(:test_env?).and_return false

      subject.registered
    end

    it "allows setting clamby options from secrets" do
      expect(MasterSetup).to receive(:test_env?).and_return false
      allow(MasterSetup).to receive(:secrets).and_return({"clamby" => {"test" => "a", "output_level" => "high"}})
      expect(Clamby).to receive(:configure).with({
        check: true,
        daemonize: true,
        fdpass: true,
        stream: true,
        output_level: 'high',
        test: "a"
      })

      subject.registered
    end

    it "does not configure in test env" do
      expect(MasterSetup).to receive(:test_env?).and_return true
      expect(Clamby).not_to receive(:configure)      

      subject.registered
    end
  end
end