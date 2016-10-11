require 'spec_helper'

describe OpenChain::SftpMonthlyArchiver do
  it 'throws an exception if an Alliance customer number is not present' do
    expect{OpenChain::SftpMonthlyArchiver.new({'ftp_folder' => 'blah'})}.to raise_error(RuntimeError, 'Alliance Customer Number Required')
  end

  it 'throws an exception if a FTP Folder is not present' do
    expect{OpenChain::SftpMonthlyArchiver.new({'alliance_customer_number' => 'blah'})}.to raise_error(RuntimeError, 'FTP Folder Required')
  end

  describe "run" do
    let (:opts) { {'notification_email' => 'blah@blah.com', 'ftp_folder' => 'blah', 'alliance_customer_number' => 'blah'} }
    let (:company) { Factory(:company, alliance_customer_number: "blah") }
    let (:entry) { 
      e = Factory(:entry, importer: company, broker_reference: "reference")
      e.broker_invoices.create! invoice_date: 1.year.ago
      e
    }
    let! (:attachment) { 
      entry.attachments.create! attached_file_name: "file.pdf", attachment_type: "Entry Packet", attached_file_size: 100
    }
    let! (:archive_setup) { AttachmentArchiveSetup.create! company_id: company.id, start_date: (Time.zone.now - 1.year).to_date }    

    context "using broker_reference_override" do
      subject { described_class.new opts }

      before :each do
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
    let (:company) { Factory(:company, alliance_customer_number: "blah") }
    let (:archive) { AttachmentArchive.create!(name: 'archive', company_id: company.id) }
    let (:entry) { Factory(:entry, importer: company, broker_reference: "reference") }
    subject {
      OpenChain::SftpMonthlyArchiver.new({'notification_email' => 'blah@blah.com', 'ftp_folder' => 'blah', 'alliance_customer_number' => 'blah'})
    }
    
    let (:attachment) {
      attachment = entry.attachments.create! attached_file_name: "file.pdf", attachment_type: "Entry Packet", attached_file_size: 100
    }

    let (:archived_attachment) {
      attachment_archives_attachment = archive.attachment_archives_attachments.create! file_name: "archived-file.pdf"
      attachment_archives_attachment.attachment = attachment
      attachment_archives_attachment.save!
      attachment_archives_attachment
    }

    let (:tempfile) { Tempfile.new "file" }

    after :each do
      tempfile.close! unless tempfile.closed?
    end

    context 'manifest file creation' do
    
      it 'creates a manifest file' do
        Timecop.freeze(Time.zone.now) do
          manifests_relation = double("manifests_relation")
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
      expect(OpenChain::S3).to receive(:get_data).with(attachment.bucket, attachment.path, instance_of(StringIO)) do |bucket, path, io|
        io.write "foo"
        io.rewind
        nil
      end

      now = Time.zone.parse "2016-01-01 00:00"
      
      # The following line is needed to instantiate the archived attachment
      archived_attachment
      expect(subject).to receive(:ftp_file) do |file, opts|
        expect(File.exists?(file.path)).to be_truthy

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
      klass = OpenChain::SftpMonthlyArchiver.new({'ftp_folder' => 'blah', 'alliance_customer_number' => 'blah'})
      klass.send_zip(archive)
      expect(ActionMailer::Base.deliveries.count).to eq(0)
    end
  end
end