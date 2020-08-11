describe OpenChain::CustomHandler::ZipFileParser do

  subject do
    s = described_class.new
    def s.process_zip_content _original_zip_file_name, _unzipped_contents, _zip_file, _s3_bucket, _s3_key, _attempt_count
      raise "Mock Me!"
    end
    s
  end

  let(:log) { InboundFile.new }

  describe "parse_file" do
    before do
      log.s3_bucket = "the_bucket"
      log.s3_path = "the_path"
    end

    it "passes file to process_file with attempt count defaulted to 1" do
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:process_file).with("zstr", "the_bucket", "the_path", 1)

      described_class.parse_file "zstr", log, {}
    end

    it "passes file to process_file with attempt count pulled from options" do
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:process_file).with("zstr", "the_bucket", "the_path", 1111)

      described_class.parse_file "zstr", log, { attempt_count: 1111 }
    end
  end

  describe "retrieve_file_data" do
    it "downloads data from S3" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("some_bucket", "some_key")
      described_class.retrieve_file_data "some_bucket", "some_key"
    end
  end

  describe "post_process_data" do
    it "closes open tempfile" do
      Tempfile.open do |tf|
        expect(tf.closed?).to eq false
        described_class.post_process_data tf
        expect(tf.closed?).to eq true
      end
    end

    it "doesn't blow up if tempfile already closed" do
      Tempfile.open do |tf|
        tf.close!
        expect(tf.closed?).to eq true
        described_class.post_process_data tf
        expect(tf.closed?).to eq true
      end
    end

    it "doesn't blow up if passed an object that doesn't support close!" do
      described_class.post_process_data "String can't be closed"
      described_class.post_process_data nil
    end
  end

  describe "get_process_from_file_data" do
    it "returns exactly what is passed to it" do
      expect(described_class.get_process_from_file_data("X")).to eq "X"
    end
  end

  describe "process_file" do
    it "unzips and processes file" do
      zip_file = File.open("spec/fixtures/files/Long_Beach_YMLU_W490374363_20200727072010.zip", "rb")

      # Verifying file names here just to ensure that we are, in fact, unzipping the file.
      zip_content_arr = ["Bill of Lading-3752035-BL W490374363.pdf",
                         "Commercial Invoice-3752035-CI_3752035_SGN4425991_CFS.pdf",
                         "Forwarders cargo receipt-3752035-FCR VNTRIPLE_USTARGETST_SGN3216506_C.pdf",
                         "Packing List-3752035-PL_3752035_SGN4425991_CFS.pdf", "index.html"]
      expect(subject).to receive(:process_zip_content).with("file.1.2.3.zip", match_property(zip_content_arr, :name),
                                                            zip_file, "the_bucket", "file.1.2.3.1510174475.zip", 3)

      expect(subject.process_file(zip_file, "the_bucket", "file.1.2.3.1510174475.zip", 3)).to be_nil
    end

    it "handles empty zip file" do
      zip_file = File.open("spec/fixtures/files/empty_zip.zip", "rb")

      expect(subject).to receive(:handle_empty_file).with("file.1.2.3.zip", zip_file)

      expect(subject.process_file(zip_file, "the_bucket", "file.1.2.3.1510174475.zip", 3)).to be_nil
    end

    it "limits unzipped files to specific types" do
      def subject.include_file? zip_entry
        File.extname(zip_entry.name).to_s.upcase == ".HTML"
      end

      zip_file = File.open("spec/fixtures/files/Long_Beach_YMLU_W490374363_20200727072010.zip", "rb")

      expect(subject).to receive(:process_zip_content).with("file.1.2.3.zip", match_property(["index.html"], :name),
                                                            zip_file, "the_bucket", "file.1.2.3.1510174475.zip", 3)

      expect(subject.process_file(zip_file, "the_bucket", "file.1.2.3.1510174475.zip", 3)).to be_nil
    end

    it "handles zip error" do
      # This isn't actually a zip file.  Opening it as a zip should throw a ZipError.
      invalid_zip_file = File.open("spec/fixtures/files/blank_report_1.xls", "rb")

      expect(subject).to receive(:handle_zip_error).with(instance_of(Zip::Error))

      expect(subject.process_file(invalid_zip_file, "the_bucket", "file.1.2.3.1510174475.zip", 3)).to be_nil
    end
  end

end