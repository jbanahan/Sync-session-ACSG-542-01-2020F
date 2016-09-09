require 'spec_helper'

describe OpenChain::SftpMonthlyArchiver do
  it 'throws an exception if an Alliance customer number is not present' do
    expect{OpenChain::SftpMonthlyArchiver.new({'ftp_folder' => 'blah'})}.to raise_error(RuntimeError, 'Alliance Customer Number Required')
  end

  it 'throws an exception if a FTP Folder is not present' do
    expect{OpenChain::SftpMonthlyArchiver.new({'alliance_customer_number' => 'blah'})}.to raise_error(RuntimeError, 'FTP Folder Required')
  end

  describe '#send_zip' do
    before do
      @company = Factory(:company)
      @archive = AttachmentArchive.create(name: 'archive', company_id: @company.id)
      @klass = OpenChain::SftpMonthlyArchiver.new({'notification_email' => 'blah@blah.com', 'ftp_folder' => 'blah', 'alliance_customer_number' => 'blah'})
    end

    describe 'manifest file creation' do
      before do
        @archive_manifests = @archive.company.attachment_archive_manifests
        @attachment_archive_manifest = AttachmentArchiveManifest.new
        allow(@archive).to receive(:company).and_return(@company)
        allow(@company).to receive(:attachment_archive_manifests).and_return(@archive_manifests)
        allow(@archive_manifests).to receive(:build).and_return(@attachment_archive_manifest)
      end

      it 'creates a manifest file' do
        expect(@attachment_archive_manifest).to receive(:generate_manifest_tempfile!)
        @klass.send_zip(@archive)
      end

      it 'closes the manifest tempfile' do
        tempfile = Tempfile.new('blah')
        allow(@attachment_archive_manifest).to receive(:generate_manifest_tempfile!).and_return(tempfile)
        expect(tempfile).to receive(:close!)
        @klass.send_zip(@archive)
      end
    end

    it 'sets the finish_at date' do
      expect(@archive.finish_at).to be_nil
      @klass.send_zip(@archive)
      expect(@archive.finish_at).to_not be_nil
    end

    it 'retrieves attachment files' do
      @archive.attachments.create
      allow(OpenChain::S3).to receive(:get_data)

      expect(OpenChain::S3).to receive(:get_data)
      @klass.send_zip(@archive)
    end

    it 'stores the attachment file in the zip file.' do
      attachment = @archive.attachments.create
      tempfile = Tempfile.new('test_file')
      tempfile.write('foo')
      tempfile.rewind
      allow(OpenChain::S3).to receive(:get_data).and_return(tempfile)
      expect(@klass).to receive(:ftp_file) do |file, opts|
        expect(File.exists?(file.path)).to be true
        Zip::File.open(file.path) do |zip_file|
          expect(zip_file.find_entry(attachment.unique_file_name)).to be_present
          expect(zip_file.find_entry('archive-manifest.xls')).to be_present
        end
      end
      @klass.send_zip(@archive)
    end

    it 'sends an email if a notification email is present' do
      klass = OpenChain::SftpMonthlyArchiver.new({'notification_email' => 'blah@blah.com', 'ftp_folder' => 'blah', 'alliance_customer_number' => 'blah'})
      klass.send_zip(@archive)
      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end

    it 'does not send an email if a Notification Email is not present' do
      klass = OpenChain::SftpMonthlyArchiver.new({'notification_email' => '', 'ftp_folder' => 'blah', 'alliance_customer_number' => 'blah'})
      klass.send_zip(@archive)
      expect(ActionMailer::Base.deliveries.count).to eq(0)
    end
  end
end