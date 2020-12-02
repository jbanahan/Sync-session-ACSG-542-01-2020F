describe OpenChain::SftpMonthlyArchiver do

  describe "initialize" do

    it "throws an exception if customer number or system code is not present" do
      expect {described_class.new({'ftp_folder' => 'blah'})}.to raise_error(RuntimeError, 'Alliance/Fenix/Cargowise Customer Number or System Code required.')
    end

    it "throws an exception if a FTP Folder is not present" do
      expect {described_class.new({'alliance_customer_number' => 'blah'})}.to raise_error(RuntimeError, 'FTP Folder Required')
    end

    context "company lookup" do
      let!(:co_with_alliance) { with_customs_management_id(Factory(:company), "alliance id") }
      let!(:co_with_fenix) { with_fenix_id(Factory(:company), "fenix id")  }
      let!(:co_with_cargowise) { with_cargowise_id(Factory(:company), "cargowise id") }
      let!(:co_with_sys_code) { Factory(:company, system_code: "sys code") }

      it "matches alliance_customer_number" do
        inst = described_class.new('ftp_folder' => 'path', 'alliance_customer_number' => "alliance id")
        expect(inst.company).to eq co_with_alliance
      end

      it "matches fenix_customer_number" do
        inst = described_class.new('ftp_folder' => 'path', 'fenix_customer_number' => "fenix id")
        expect(inst.company).to eq co_with_fenix
      end

      it "matches cargowise_customer_number" do
        inst = described_class.new('ftp_folder' => 'path', 'cargowise_customer_number' => "cargowise id")
        expect(inst.company).to eq co_with_cargowise
      end

      it "matches system_code" do
        inst = described_class.new('ftp_folder' => 'path', 'system_code' => "sys code")
        expect(inst.company).to eq co_with_sys_code
      end
    end
  end

  describe "run" do
    let (:opts) { {'notification_email' => 'blah@blah.com', 'ftp_folder' => 'blah', 'alliance_customer_number' => 'blah'} }
    let (:company) { with_customs_management_id(create(:company), "blah") }
    let! (:archive_setup) { AttachmentArchiveSetup.create! company_id: company.id, start_date: (Time.zone.now - 1.year).to_date }

    let (:entry) do
      e = create(:entry, importer: company, broker_reference: "reference")
      e.broker_invoices.create! invoice_date: 1.year.ago
      e
    end

    let! (:attachment) do
      entry.attachments.create! attached_file_name: "file.pdf", attachment_type: "Entry Packet", attached_file_size: 100
    end

    it "allows override of filename prefix" do
      opts.merge!('filename_prefix' => "new_prefix")
      now = Time.zone.parse("2016-10-05 00:00")
      archive_setup.update! start_date: now - 2.years
      entry.broker_invoices.first.update! invoice_date: now - 1.year
      allow(OpenChain::S3).to receive(:get_data)
      Timecop.freeze(now) { described_class.new(opts).run }

      archive = AttachmentArchive.last
      expect(archive).not_to be_nil
      expect(archive.name).to eq "new_prefix-2016-09.zip"
    end

    context "using broker_reference_override" do
      subject { described_class.new opts }

      before do
        opts["broker_reference_override"] = [entry.broker_reference]
      end

      it "builds an archive and sends it" do
        now = Time.zone.parse("2016-10-05 00:00")

        # Just make sure something was ftp'ed...we'll do more extensive testing below with the send_zip method
        allow(OpenChain::S3).to receive(:get_data)
        expect(subject).to receive(:ftp_file)

        Timecop.freeze(now) do
          subject.run
        end

        archive = AttachmentArchive.last
        expect(archive).not_to be_nil
        expect(archive.name).to eq "blah-2016-09.zip"
        expect(archive.finish_at.to_i).to eq now.to_i
      end
    end
  end

  describe '#send_zip' do
    subject do
      described_class.new({'notification_email' => 'blah@blah.com', 'ftp_folder' => 'blah', 'alliance_customer_number' => 'blah'})
    end

    let (:company) { with_customs_management_id(create(:company), "blah") }
    let (:archive) { AttachmentArchive.create!(name: 'archive', company_id: company.id) }
    let (:entry) { create(:entry, importer: company, broker_reference: "reference") }
    let! (:archive_setup) { entry.importer.create_attachment_archive_setup(start_date: 1.year.ago) }
    let (:tempfile) { Tempfile.new "file" }

    let (:attachment) do
      entry.attachments.create! attached_file_name: "file.pdf", attachment_type: "Entry Packet", attached_file_size: 100
    end

    let (:archived_attachment) do
      attachment_archives_attachment = archive.attachment_archives_attachments.create! file_name: "archived-file.pdf"
      attachment_archives_attachment.attachment = attachment
      attachment_archives_attachment.save!
      attachment_archives_attachment
    end

    after do
      tempfile.close! unless tempfile.closed?
    end

    context 'manifest file creation' do
      it 'creates a manifest file' do
        Timecop.freeze(Time.zone.now) do
          manifests_relation = instance_double("manifests_relation")
          manifest = instance_double("AttachmentArchiveManifest")
          expect(archive.company).to receive(:attachment_archive_manifests).and_return manifests_relation
          expect(manifests_relation).to receive(:build).and_return manifest
          expect(manifest).to receive(:generate_manifest_tempfile!).with(1.year.ago).and_return tempfile

          subject.send_zip(archive)
        end
        expect(tempfile).to be_closed
      end
    end

    it 'stores the attachment file in the zip file.' do
      expect(OpenChain::S3).to receive(:get_data).with(attachment.bucket, attachment.path, instance_of(StringIO)) do |_bucket, _path, io|
        io.write "foo"
        io.rewind
        nil
      end

      now = Time.zone.parse "2016-01-01 00:00"

      # The following line is needed to instantiate the archived attachment
      archived_attachment
      expect(subject).to receive(:ftp_file) do |file, _opts|
        expect(File.exist?(file.path)).to be_truthy

        Zip::File.open(file.path) do |zip_file|
          expect(zip_file.find_entry(archived_attachment.output_path)).to be_present
          expect(zip_file.file.read(archived_attachment.output_path)).to eq "foo"
          expect(zip_file.find_entry("ArchiveManifest-2016-01-01.xls")).to be_present
        end
      end

      Timecop.freeze(now) do
        subject.send_zip(archive)
      end

      # validate an email is sent
      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end

    it 'does not send an email if a Notification Email is not present' do
      klass = described_class.new({'ftp_folder' => 'blah', 'alliance_customer_number' => 'blah'})
      klass.send_zip(archive)
      expect(ActionMailer::Base.deliveries.count).to eq(0)
    end
  end
end
