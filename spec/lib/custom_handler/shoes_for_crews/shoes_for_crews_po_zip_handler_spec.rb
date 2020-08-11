describe OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoZipHandler do

  describe "process_file" do
    let(:zip_path) { "spec/fixtures/files/shoes_for_crews_pos.zip"}
    let(:file) { File.open(zip_path, "rb")}
    let(:log) { InboundFile.new }

    before do
      allow(subject).to receive(:inbound_file).and_return log
    end

    after do
      file.close
    end

    it "extracts and ftps all .xls files in zip" do
      spreadsheet = nil
      expect(subject).to receive(:ftp_file) do |file, info|
        expect(info[:folder]).to eq "_shoes_po"
        expect(info[:username]).to eq "www-vfitrack-net"
        expect(file.original_filename).to eq "12164.xls"

        spreadsheet = Spreadsheet.open(file)
        nil
      end

      subject.process_file file, "bucket", "path", 1
      # If we can read that there's worksheets in the file, that's good enough for the test
      expect(spreadsheet.worksheets.length).to eq 1
      expect(log).to have_info_message "Extracted file 12164.xls"
    end
  end
end