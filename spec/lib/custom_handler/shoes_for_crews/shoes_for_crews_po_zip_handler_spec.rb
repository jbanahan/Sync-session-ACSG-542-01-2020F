describe OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoZipHandler do 

  subject { described_class }

  let (:zip_path) { "spec/fixtures/files/shoes_for_crews_pos.zip"}
  let (:file) { File.open(zip_path, "rb")}

  after(:each) do 
    file.close
  end

  describe "process_from_s3" do
    it "uses s3 to download file" do
      file = instance_double(Tempfile)
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path").and_yield file
      expect(subject).to receive(:process_file).with file
      subject.process_from_s3 "bucket", "path"
    end
  end

  describe "process_file" do
    it "unzips and extracts all xls files and calls send_file with them" do
      file_data = nil
      file_name = nil
      expect(subject).to receive(:send_file) do |file|
        file_name = file.original_filename
        file_data = Spreadsheet.open(file)
      end

      subject.process_file file

      expect(file_name).to eq "12164.xls"
      # If we can read that there's worksheets in the file, that's good enough for the test
      expect(file_data.worksheets.length).to eq 1
    end
  end

  describe "send_file" do
    it "sends the file to the right location" do
      fake_file = instance_double(Tempfile)
      expect(subject).to receive(:ftp_file).with(fake_file, hash_including(folder: "_shoes_po"))
      subject.send_file fake_file
    end
  end
end