describe OpenChain::CustomHandler::Ascena::AscenaSupplementalFileParser do
  let(:csv) do
    # header
    ",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,\n" \
      ",,,,,,,,,,,,,,,,,,,,,316-2523440-1,,,,,,,,,,,,,,,ASCENA TRADE SERVICES,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,\n" \
      ",,,,,,,,,,,,,,,,,,,,,316-2523440-1,,,,,,,,,,,,,,,ASCENA TRADE SERVICES,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,"
  end

  describe "parse" do
    let!(:ent) { Factory(:entry, entry_number: "21612345671", broker_reference: "1234567", source_system: Entry::KEWILL_SOURCE_SYSTEM) }

    before do
      allow(described_class).to receive(:inbound_file).and_return InboundFile.new(s3_path: "path/to/some_file.csv")
    end

    it "attaches file to existing entry" do
      ent.update! entry_number: "31625234401", broker_reference: "2523440"

      t = Tempfile.new
      expect(Tempfile).to receive(:open).with(["suppl", ".csv"]).and_yield t

      described_class.parse csv, original_filename: "some_file.csv"
      ent.reload

      expect(ent.attachments.count).to eq 1
      att = ent.attachments.first
      expect(att.uploaded_by).to eq User.integration
      expect(att.attachment_type).to eq "FTZ Supplemental Data"
      expect(att.attached_file_name).to eq "some_file.csv"

      t.rewind
      expect(t.read).to eq csv
      t.close

      expect(ent.entity_snapshots.count).to eq 1
      snap = ent.entity_snapshots.first
      expect(snap.user).to eq User.integration
      expect(snap.context).to eq "path/to/some_file.csv"
    end

    it "attaches file to new entry if none exists" do
      t = Tempfile.new
      expect(Tempfile).to receive(:open).with(["suppl", ".csv"]).and_yield t

      described_class.parse csv, original_filename: "some_file.csv"
      ent = Entry.find_by entry_number: "31625234401"

      expect(ent.broker_reference).to eq "2523440"

      expect(ent.attachments.count).to eq 1
      att = ent.attachments.first
      expect(att.uploaded_by).to eq User.integration
      expect(att.attachment_type).to eq "FTZ Supplemental Data"
      expect(att.attached_file_name).to eq "some_file.csv"

      t.rewind
      expect(t.read).to eq csv
      t.close

      expect(ent.entity_snapshots.count).to eq 1
      snap = ent.entity_snapshots.first
      expect(snap.user).to eq User.integration
      expect(snap.context).to eq "path/to/some_file.csv"
    end

    it "raises exception if entry number missing" do
      csv.gsub! "316-2523440-1", ""
      expect {described_class.parse csv, original_filename: "some_file.csv"}.to raise_error "Entry number missing from supplemental file."
    end
  end
end
