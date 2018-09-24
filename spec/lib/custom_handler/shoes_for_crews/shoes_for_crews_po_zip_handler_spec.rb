describe OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoZipHandler do 

  subject { described_class }

  let (:zip_path) { "spec/fixtures/files/shoes_for_crews_pos.zip"}
  let (:file) { File.open(zip_path, "rb")}

  after(:each) do 
    file.close
  end

  describe "retrieve_file_data" do
    it "uses s3 to download file and returns a zip stream" do
      expect(OpenChain::S3).to receive(:get_data) do |bucket, key, io|
        expect(bucket).to eq "bucket"
        expect(key).to eq "path"

        io.write file.read
        nil
      end
      
      zip = subject.retrieve_file_data("bucket", "path")
      expect(zip).to be_a Zip::InputStream
      expect(zip.get_next_entry).not_to be_nil
    end
  end

  describe "parse_file" do
    let! (:log) { InboundFile.new }
    let (:zip) { Zip::InputStream.open(file) }

    it "extracts and ftps all .xls files in zip" do
      spreadsheet = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file, info|
        expect(info[:folder]).to eq "_shoes_po"
        expect(info[:username]).to eq "www-vfitrack-net"
        expect(file.original_filename).to eq "12164.xls"

        spreadsheet = Spreadsheet.open(file)
        nil
      end

      subject.parse_file zip, log
      # If we can read that there's worksheets in the file, that's good enough for the test
      expect(spreadsheet.worksheets.length).to eq 1
      expect(log).to have_info_message "Extracted file 12164.xls"
    end
  end
end