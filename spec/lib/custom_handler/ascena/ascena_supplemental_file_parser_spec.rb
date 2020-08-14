describe OpenChain::CustomHandler::Ascena::AscenaSupplementalFileParser do
  let(:csv) do
    # header
    ",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,\n" \
      ",,,,,,,,,,,,,,,,,,,,,316-2523440-1,,,,,,,,,,,,,,,ASCENA TRADE SERVICES,,,,,,,,,,,,,,,,,,,PO1,,,,,,,,,,,,,,,,,,,,,,\n" \
      ",,,,,,,,,,,,,,,,,,,,,316-2523440-1,,,,,,,,,,,,,,,ASCENA TRADE SERVICES,,,,,,,,,,,,,,,,,,,PO2,,,,,,,,,,,,,,,,,,,,,,"
  end

  describe "parse" do
    let!(:ent) { Factory(:entry, entry_number: "21612345671", broker_reference: "1234567", source_system: Entry::KEWILL_SOURCE_SYSTEM) }
    let(:inbound) { InboundFile.new(s3_path: "path/to/some_file.csv") }

    before do
      allow(subject).to receive(:inbound_file).and_return inbound
    end

    it "attaches file to existing entry" do
      ent.update! entry_number: "31625234401", broker_reference: "2523440"

      t = Tempfile.new
      expect(Tempfile).to receive(:open).with(["suppl", ".csv"]).and_yield t

      subject.parse csv, original_filename: "some_file.csv"
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

      subject.parse csv, original_filename: "some_file.csv"
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

    it "handles single-line files (+ header)" do
      short_csv = csv.split("\n")[0..1].join("\n")

      t = Tempfile.new
      expect(Tempfile).to receive(:open).with(["suppl", ".csv"]).and_yield t

      subject.parse short_csv, original_filename: "some_file.csv"
      ent = Entry.find_by entry_number: "31625234401"

      expect(ent.broker_reference).to eq "2523440"
    end

    context "errors" do
      before { Factory(:mailing_list, system_code: "ascena_ftz_validations", email_addresses: "tufnel@stonehenge.biz") }

      it "sends email if first entry number is missing" do
        csv.gsub! "316-2523440-1", ""

        subject.parse csv, original_filename: "some_file.csv"

        expect(inbound).to have_reject_message "Entry Numbers are missing."
        expect(ActionMailer::Base.deliveries.length).to eq 1
        m = ActionMailer::Base.deliveries.first
        expect(m.to).to eq ["tufnel@stonehenge.biz"]
        expect(m.subject).to eq "Supplemental Data File was Rejected for Missing Data"
        expect(m.body).to include "The Supplemental Data File some_file.csv was not processed due to missing Entry Numbers. "\
                                  "Please add the correct Entry Numbers to the Supplemental File and resend for processing."
        expect(m.attachments.length).to eq 1
        expect(m.attachments["some_file.csv"]).not_to be_nil
        expect(m.attachments["some_file.csv"].read).to eq csv

        expect(ent.entity_snapshots.count).to eq 0
      end

      it "sends email if any PO number is missing" do
        csv.gsub! "PO2", ""

        subject.parse csv, original_filename: "some_file.csv"

        expect(inbound).to have_reject_message "PO Numbers are missing."
        expect(ActionMailer::Base.deliveries.length).to eq 1
        m = ActionMailer::Base.deliveries.first
        expect(m.to).to eq ["tufnel@stonehenge.biz"]
        expect(m.subject).to eq "Supplemental Data File was Rejected for Missing Data"
        expect(m.body).to include "The Supplemental Data File some_file.csv was not processed due to missing PO Numbers. "\
                                  "Please add the correct PO Numbers to the Supplemental File and resend for processing."
        expect(m.attachments.length).to eq 1
        expect(m.attachments["some_file.csv"]).not_to be_nil
        expect(m.attachments["some_file.csv"].read).to eq csv

        expect(ent.entity_snapshots.count).to eq 0
      end
    end
  end
end
