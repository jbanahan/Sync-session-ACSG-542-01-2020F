describe OpenChain::CustomHandler::Target::TargetDocumentPacketZipGenerator do

  describe "create_document_packets" do

    let (:entry) { Factory(:entry, master_bills_of_lading: "MBOL12345") }
    let! (:attachment_7501) do
      a = entry.attachments.create! attachment_type: "Entry Summary - F7501", attached_file_name: "summary.txt"
      allow(a).to receive(:download_to_tempfile).and_yield(tempfile_7501)

      a
    end
    let (:tempfile_7501) do
      # We're relying on the builder interface to allow handling just regular IO objects
      # here, so we're not actually going to use a tempfile
      io = StringIO.new
      io << "7501"
      io.rewind

      io
    end

    let! (:attachment_other_doc) do
      a = entry.attachments.create! attachment_type: "Other USC Documents", attached_file_name: "other.txt"
      allow(a).to receive(:download_to_tempfile).and_yield(tempfile_other)

      a
    end
    let (:tempfile_other) do
      io = StringIO.new
      io << "other"
      io.rewind

      io
    end

    let! (:attachment_invoice) do
      a = entry.attachments.create! attachment_type: "Commercial Invoice", attached_file_name: "invoice.txt"
      allow(a).to receive(:download_to_tempfile).and_yield(tempfile_invoice)

      a
    end
    let (:tempfile_invoice) do
      io = StringIO.new
      io << "invoice"
      io.rewind

      io
    end

    let (:target_xml_generator) do
      xml = instance_double(OpenChain::CustomHandler::Target::TargetDocumentPacketXmlGenerator)
      allow(xml).to receive(:write_xml) do |doc, io|
        io << doc.to_s
        nil
      end
      xml
    end

    let (:summary_xml) do
      REXML::Document.new("<summary />")
    end

    let (:other_xml) do
      REXML::Document.new("<other />")
    end

    it "extracts documents from entry and zips them" do
      allow(subject).to receive(:xml_generator).and_return target_xml_generator
      expect(target_xml_generator).to receive(:generate_xml).with(entry, "MBOL12345", [attachment_7501]).and_return summary_xml
      expect(target_xml_generator).to receive(:generate_xml).with(entry, "MBOL12345", [attachment_other_doc, attachment_invoice]).and_return other_xml

      now = Time.zone.now
      in_tz = now.in_time_zone("America/New_York")

      zip_files = []
      Timecop.freeze(now) do
        subject.create_document_packets(entry) do |zip|
          expect(zip.original_filename).to eq "TDOX_5003461_#{in_tz.strftime("%Y%m%d%H%M%S%L")}.zip"

          output = StringIO.new
          IO.copy_stream(zip, output)
          output.rewind

          zip_files << output
        end
      end

      expect(zip_files.length).to eq 2

      # The first file should be the 7501 docs
      zip = Zip::File.open_buffer(zip_files[0])
      expect(zip.find_entry("METADATA_5003461_#{in_tz.strftime("%Y%m%d%H%M%S%L")}.xml")).to be_present
      expect(zip.find_entry("METADATA_5003461_#{in_tz.strftime("%Y%m%d%H%M%S%L")}.xml").get_input_stream.read).to eq "<summary/>"
      expect(zip.find_entry("summary.txt")).to be_present
      expect(zip.find_entry("summary.txt").get_input_stream.read).to eq "7501"

      # The second file should be the other docs
      zip = Zip::File.open_buffer(zip_files[1])
      expect(zip.find_entry("METADATA_5003461_#{in_tz.strftime("%Y%m%d%H%M%S%L")}.xml")).to be_present
      expect(zip.find_entry("METADATA_5003461_#{in_tz.strftime("%Y%m%d%H%M%S%L")}.xml").get_input_stream.read).to eq "<other/>"
      expect(zip.find_entry("other.txt")).to be_present
      expect(zip.find_entry("other.txt").get_input_stream.read).to eq "other"
      expect(zip.find_entry("invoice.txt")).to be_present
      expect(zip.find_entry("invoice.txt").get_input_stream.read).to eq "invoice"
    end

    it "generates zip files for every bill of lading present in the entry" do
      entry.master_bills_of_lading << "\n MBOL2"
      allow(subject).to receive(:xml_generator).and_return target_xml_generator
      expect(target_xml_generator).to receive(:generate_xml).with(entry, "MBOL12345", [attachment_7501]).and_return summary_xml
      expect(target_xml_generator).to receive(:generate_xml).with(entry, "MBOL12345", [attachment_other_doc, attachment_invoice]).and_return other_xml
      expect(target_xml_generator).to receive(:generate_xml).with(entry, "MBOL2", [attachment_7501]).and_return summary_xml
      expect(target_xml_generator).to receive(:generate_xml).with(entry, "MBOL2", [attachment_other_doc, attachment_invoice]).and_return other_xml

      zip_files = 0
      subject.create_document_packets(entry) do |_zip|
        zip_files += 1
      end

      expect(zip_files).to eq 4
    end
  end

end