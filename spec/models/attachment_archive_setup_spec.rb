describe AttachmentArchiveSetup do
  let (:importer) { Factory(:company) }
  let (:entry) { Factory(:entry, importer: importer, arrival_date: 1.month.ago, broker_reference: "REF") }
  let (:archive_setup) { importer.create_attachment_archive_setup(start_date: 1.year.ago) }
  let (:attachment) { entry.attachments.create!(attached_file_name: 'a.pdf', attached_file_size: 100) }
  let (:attachment_2) { entry.attachments.create!(attached_file_name: 'b.pdf', attached_file_size: 100, is_private: false)}
  let (:invoice) { Factory(:broker_invoice, entry: entry, invoice_date: (Time.current.midnight - 30.days) - 1.second) }

  describe "create_entry_archive!" do

    before do
      archive_setup
      attachment
      attachment_2
      invoice
    end

    it "includes relevant attachments" do
      archive = archive_setup.create_entry_archive! "my name", 5.megabytes
      expect(archive).to be_persisted
      expect(archive.name).to eq("my name")
      expect(archive.company).to eq(importer)
      expect(archive.attachments.length).to eq(2)
      expect(archive.attachments).to include(attachment, attachment_2)
    end

    it "stops at max size" do
      # Because of the indeterminate ordering of the archive (attachments are only ordered by entry arrival date),
      # just make sure 1 of the 2 attachments were included in the archive
      att = archive_setup.create_entry_archive!("my name", 199).attachments.to_a
      expect(att.length).to eq(1)
      raise("Archive attachments should have included @att or @att2") unless att[0].id == attachment.id || att[0].id == attachment_2.id
    end

    it "does not include non-entry attachments" do
      Attachment.create!(attached_file_name: 'no.txt', attached_file_size: 1)
      archive = archive_setup.create_entry_archive!("my name", 1000)
      expect(archive.attachments.length).to eq(2)
      expect(archive.attachments).to include(attachment, attachment_2)
    end

    it "does not include attachments for other importers" do
      e2 = Factory(:entry)
      e2.attachments.create(attached_file_name: 'c.txt', attached_file_size: 1)
      archive = archive_setup.create_entry_archive!("my name", 1000)
      expect(archive.attachments.length).to eq(2)
      expect(archive.attachments).to include(attachment, attachment_2)
    end

    it "does not include attachments invoiced before start_date" do
      archive_setup.update(start_date: Time.zone.now)
      expect(archive_setup.create_entry_archive!("my name", 1000).attachments.length).to eq(0)
    end

    it "does not include attachments invoiced less than 30 days ago" do
      invoice.update(invoice_date: Time.current.midnight - 29.days)
      expect(archive_setup.create_entry_archive!("my name", 1000).attachments.length).to eq(0)
    end

    it "includes attachments that have one invoice newer than 30 days ago" do
      Factory(:broker_invoice, entry: entry, invoice_date: Time.current)
      expect(archive_setup.create_entry_archive!("my name", 1000).attachments.length).to eq(2)
    end

    it "includes attachments only once" do
      # This is really just to verify distinct is being used
      Factory(:broker_invoice, entry: entry, invoice_date: 40.days.ago)
      expect(archive_setup.create_entry_archive!("my name", 1000).attachments.length).to eq(2)
    end

    it "does not include attachments on another archive" do
      other_archive = AttachmentArchive.create!(name: 'x', company: importer)
      other_archive.attachments << attachment
      expect(archive_setup.create_entry_archive!("my name", 1000).attachments.to_a).to eq([attachment_2])
    end

    it "onlies include 'Archive Packet' attachments if there are any present on an entry" do
      att3 = entry.attachments.create! attached_file_name: 'b.txt', attached_file_size: 100, attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
      expect(archive_setup.create_entry_archive!("my name", 1000).attachments.to_a).to eq [att3]
    end

    it "alsoes include non-stitchable attachments if any 'Archive Packets' are on the entry" do
      att3 = entry.attachments.create! attached_file_name: 'b.pdf', attached_file_size: 100, attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
      attachment.update! attached_file_name: 'test.non-stitchable'

      att = archive_setup.create_entry_archive!("my name", 1000).attachments.to_a
      expect(att.size).to eq(2)
      expect(att).to include(att3)
      expect(att).to include(attachment)
    end

    it "includes invoices from last month when using 'previous month' archiving scheme" do
      archive_setup.update! archive_scheme: "PREVIOUS_MONTH"
      invoice.update! invoice_date: Time.current.midnight.at_beginning_of_month - 1.day
      archive = archive_setup.create_entry_archive! "my name", 5.megabytes
      expect(archive.attachments.length).to eq(2)
      expect(archive.attachments).to include(attachment, attachment_2)
    end

    it "excludes invoices from this month when using 'previous month' archiving scheme" do
      archive_setup.update! archive_scheme: "PREVIOUS_MONTH"
      invoice.update! invoice_date: Time.current.midnight.at_beginning_of_month
      expect(archive_setup).not_to be_entry_attachments_available
    end

    it "excludes invoices that occur after the end date" do
      archive_setup.update! end_date: Date.new(2013, 1, 1)
      expect(archive_setup).not_to be_entry_attachments_available
    end

    it "excludes private attachments" do
      attachment.update! is_private: true
      archive = archive_setup.create_entry_archive! "my name", 5.megabytes
      expect(archive.attachments).not_to include(attachment)
    end

    it "allows supplying list of file numbers to archive for the given importer" do
      # Setup an end date, that should show that the override list is taking precedence
      archive_setup.update! end_date: Date.new(2013, 1, 1)

      archive_setup.broker_reference_override = [entry.broker_reference]
      att = archive_setup.create_entry_archive!("my name", 5.megabytes).attachments.to_a
      expect(att.length).to eq 2
    end

    context "by release date" do
      before do
        archive_setup.update! archive_scheme: "RELEASE_PREVIOUS_MONTH"
        entry.update! release_date: (Time.zone.now.at_beginning_of_month - 1.second)
        entry.broker_invoices.destroy_all
      end

      it "returns entries release prior to this month" do
        archive = archive_setup.create_entry_archive! "my name", 5.megabytes
        expect(archive).to be_persisted
        expect(archive.attachments.length).to eq(2)
      end

      it "skips entries released this month" do
        entry.update! release_date: Time.zone.now
        archive = archive_setup.create_entry_archive! "my name", 5.megabytes
        expect(archive.attachments.length).to eq(0)
      end

      it "skips entries released prior to archive start" do
        archive_setup.start_date = Date.new(2019, 9, 1)
        entry.update! release_date: Date.new(2019, 8, 1)

        archive = archive_setup.create_entry_archive! "my name", 5.megabytes
        expect(archive.attachments.length).to eq(0)
      end

      it "skips entries released after archive end date" do
        archive_setup.end_date = Date.new(2019, 8, 1)
        entry.update! release_date: Date.new(2019, 8, 15)

        archive = archive_setup.create_entry_archive! "my name", 5.megabytes
        expect(archive.attachments.length).to eq(0)
      end
    end
  end

  describe "entry_attachments_available?" do
    before do
      archive_setup
      attachment
      attachment_2
      invoice
    end

    it "returns true if unarchived attachments exist for company" do
      expect(archive_setup).to be_entry_attachments_available
    end

    it "returns false if no unarchived attachments exist for company" do
      archive_setup.create_entry_archive! "name", 5.megabytes
      expect(archive_setup).not_to be_entry_attachments_available
    end

    it "uses override list if given" do
      # Use the end_date so that if the override list wasn't used, it would block any results from being available
      archive_setup.update! end_date: Date.new(2013, 1, 1)
      archive_setup.broker_reference_override = [entry.broker_reference]
      expect(archive_setup.entry_attachments_available?).to be_truthy
    end
  end

  describe "create_entry_archives_for_reference_numbers!" do

    subject { described_class }

    before do
      archive_setup
      attachment
      attachment_2
      invoice
    end

    it "creates an archive" do
      now = Time.zone.now

      archives = nil
      Timecop.freeze(now) { archives = subject.create_entry_archives_for_reference_numbers! 1000, importer, [entry.broker_reference] }

      expect(archives.length).to eq 1
      archive = archives.first
      expect(archive.attachments).to include attachment, attachment_2
      expect(archive.start_at.to_i).to eq now.to_i
      expect(archive.name).to eq "#{importer.name}-1"
      expect(archive.company).to eq importer
    end

    it "does not include private attachments" do
      attachment_2.update! is_private: true
      archives = subject.create_entry_archives_for_reference_numbers! 1000, importer, [entry.broker_reference]
      expect(archives.first.attachments).to include attachment
      expect(archives.first.attachments).not_to include attachment_2
    end

    it "creates multiple archives when there are too many files for one archive" do
      entry_2 = Factory(:entry, broker_reference: "file2", importer: importer, arrival_date: Time.zone.now.to_date)
      attachment_3 = entry_2.attachments.create!(attached_file_name: '3.pdf', attached_file_size: 100)

      archives = subject.create_entry_archives_for_reference_numbers! 200, importer, [entry.broker_reference, entry_2.broker_reference]
      expect(archives.length).to eq 2

      a = archives.first
      expect(a.name).to eq "#{importer.name}-1"
      expect(a.attachments).to include(attachment, attachment_2)

      a = archives.second
      expect(a.name).to eq "#{importer.name}-2"
      expect(a.attachments).to include(attachment_3)
    end

    it "errors if can't fit documents for a single entry below max archive size" do
      # rubocop:disable Layout/LineLength
      expect { subject.create_entry_archives_for_reference_numbers! 100, importer, [entry.broker_reference] }.to raise_error "Unable to fit any documents in a single archive.  Try setting the archive size higher than 100."
      # rubocop:enable Layout/LineLength

      # This should also rollback the archive creation
      expect(importer.attachment_archives.length).to eq 0
    end

    it "removes attachmenst from any other archive" do
      another_archive = AttachmentArchive.create! name: "Test", start_at: Time.zone.now
      another_archive.attachment_archives_attachments.create! attachment_id: attachment.id, file_name: "att.pdf"

      archives = subject.create_entry_archives_for_reference_numbers! 1000, importer, [entry.broker_reference]
      expect(archives.first.attachments).to include attachment

      another_archive.reload
      expect(another_archive.attachments).not_to include attachment
    end

    context "with combine attachments enabled" do
      before do
        archive_setup.update! combine_attachments: true
      end

      it "skips files for an entry that should already be in the archive packet" do
        attachment.update! attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE

        archives = subject.create_entry_archives_for_reference_numbers! 1000, importer, [entry.broker_reference]
        expect(archives.first.attachments).to include attachment
        expect(archives.first.attachments).not_to include attachment_2
      end

      it "includes non-combinable attachment types with archive packet" do
        attachment.update! attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
        attachment_2.update! attached_file_name: "file.xls"

        archives = subject.create_entry_archives_for_reference_numbers! 1000, importer, [entry.broker_reference]
        expect(archives.first.attachments).to include attachment, attachment_2
      end

      it "includes all attachments if an archive packet isn't found" do
        archives = subject.create_entry_archives_for_reference_numbers! 1000, importer, [entry.broker_reference]
        expect(archives.first.attachments).to include attachment, attachment_2
      end
    end

  end

  describe "setups_for" do
    subject { described_class }

    let (:company) { Factory(:company) }
    let (:parent) do
      p = Factory(:company)
      p.linked_companies << company
      p
    end

    let (:parent_archive) { parent.create_attachment_archive_setup }
    let (:child_archive) { company.create_attachment_archive_setup }

    it "finds parent and child archives" do
      parent_archive
      child_archive

      setups = subject.setups_for company
      expect(setups.length).to eq 2
      # The child archive should always be first
      expect(setups.first).to eq child_archive
      expect(setups.second).to eq parent_archive
    end

    it "finds child archive" do
      child_archive
      parent

      setups = subject.setups_for company
      expect(setups.length).to eq 1
      expect(setups).to include child_archive
    end

    it "finds parent archive" do
      parent_archive

      setups = subject.setups_for company
      expect(setups.length).to eq 1
      expect(setups).to include parent_archive
    end

    it "returns blank array" do
      parent

      setups = subject.setups_for company
      expect(setups.length).to eq 0
    end
  end
end
