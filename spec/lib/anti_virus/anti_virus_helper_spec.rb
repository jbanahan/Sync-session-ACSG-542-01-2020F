describe OpenChain::AntiVirus::AntiVirusHelper do

  subject {
    Class.new do
      extend OpenChain::AntiVirus::AntiVirusHelper
    end
  }

  describe "validate_file" do
    let (:file_path) { "/path/to/file.txt" }


    it "returns file path if file exists" do
      expect(File).to receive(:file?).with(file_path).and_return true
      expect(subject.validate_file file_path).to eq file_path
    end

    it "errors if file doesn't exist" do
      expect(File).to receive(:file?).with(file_path).and_return false
      expect { subject.validate_file file_path }.to raise_error Errno::ENOENT, "No such file or directory - #{file_path}"
    end
  end

  describe "get_file_path" do

    let (:file_path) { "/path/to/file.txt" }
    let (:file) {
      File.open(__FILE__, "r")
    }

    after :each do
      file.close unless file.closed?
    end

    it "allows using String" do
      expect(subject.get_file_path file_path).to eq file_path
    end

    it "allows using a Pathname object" do
      expect(subject.get_file_path Pathname.new(file_path)).to eq "/path/to/file.txt"
    end

    it "allows using a File object" do
      expect(subject.get_file_path file).to eq __FILE__
    end
  end

end