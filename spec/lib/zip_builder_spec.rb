describe OpenChain::ZipBuilder do

  describe "create_zip_builder" do
    subject { described_class }

    let (:string_io) do
      io = StringIO.new
      io << "Testing"
      io.rewind
      io
    end

    let (:file) { File.open("spec/fixtures/files/attorney.png", "rb") }
    let (:tempfile) { Tempfile.new(["test", ".zip"]) }

    after do
      tempfile.close!
      file.close
    end

    it "creates a zip file and adds files to it" do
      # This is pretty much just an integration test, that tests the
      # zip building works and can have files added to it utilizing
      # the standard process flow
      zip_tempfile = nil
      subject.create_zip_builder("file.zip") do |builder|
        expect(builder).to be_instance_of(described_class)

        builder.add_file("file.txt", string_io)
        builder.add_file("subdir/file.png", file)

        zip_tempfile = builder.to_tempfile
        expect(zip_tempfile.original_filename).to eq "file.zip"

        IO.copy_stream(zip_tempfile, tempfile)
      end

      expect(zip_tempfile).to be_closed

      # Now verify the zip can be read and its contents are as expected
      Zip::File.open(tempfile.path) do |zip|
        expect(zip.find_entry("file.txt")).to be_present
        expect(zip.find_entry("file.txt").get_input_stream.read).to eq "Testing"

        expect(zip.find_entry("subdir/file.png")).to be_present
        file.rewind
        expect(zip.find_entry("subdir/file.png").get_input_stream.read).to eq file.read
      end
    end

    it "raises an error if builder is utilized after being closed" do
      builder = nil
      subject.create_zip_builder("file.zip") do |b|
        builder = b
      end
      expect { builder.add_file "file.txt", string_io }.to raise_error "You cannot add new files to closed zip files."
    end

    it "raises an error if builder is attempted to be transformed into a tempfile after already being closed" do
      builder = nil
      subject.create_zip_builder("file.zip") do |b|
        builder = b
      end

      expect { builder.to_tempfile }.to raise_error "You cannot access the tempfile of a closed zip builder."
    end

    it "raises an error if attempting to add files after converting to a tempfile" do
      expect do
        subject.create_zip_builder("file.zip") do |builder|
          builder.add_file("file.txt", string_io)
          builder.to_tempfile
          builder.add_file("subdir/file.png", file)
        end
      end.to raise_error "You cannot add new files to zip builders that have been converted to tempfiles."
    end
  end
end