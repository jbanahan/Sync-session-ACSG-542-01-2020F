describe OpenChain::CreateZipSupport do
  subject {
    Class.new do
      include OpenChain::CreateZipSupport
    end.new
  }


  describe "zip_attachments" do
    let (:attachment_1) {
      a = instance_double(Attachment)
      allow(a).to receive(:bucket).and_return "bucket"
      allow(a).to receive(:path).and_return "attachment_1"
      allow(a).to receive(:attached_file_name).and_return "file.txt"

      a
    }

    it "zips all given attachments into a single zip file and yields the tempfile verision of it" do
      expect(OpenChain::S3).to receive(:get_data) do |bucket, path, io|
        expect(bucket).to eq "bucket"
        expect(["attachment_1", "attachment_2"]).to include path

        # Just read out a file and write it to the IO object, rewinding it like get_data does
        io << IO.read("spec/fixtures/files/attorney.png", mode: "rb")
        io.rewind
      end

      subject.zip_attachments("file.zip", [attachment_1]) do |tempfile|
        expect(tempfile).to be_a Tempfile
        expect(tempfile.original_filename).to eq "file.zip"
        # Make sure the tempfile has something in it...this is checking the re-open condition workaround
        expect(tempfile.size).not_to eq 0

        # Open the zip file, extract the attachment and make sure it's byte compatable with the file handed to the code to be zipped
        Zip::File.open(tempfile.path) do |zip|
          expect(zip.find_entry("file.txt")).to be_present
          expect(zip.find_entry("file.txt").get_input_stream.read).to eq IO.read("spec/fixtures/files/attorney.png", mode: "rb")
        end
      end
    end
  end
end