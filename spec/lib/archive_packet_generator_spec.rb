describe OpenChain::ArchivePacketGenerator do
  describe 'has_archive?' do
    let(:entry) { create(:entry) }

    it 'returns false if entry does not have an archive' do
      entry.attachments.destroy_all
      entry.save!
      expect(described_class.archive?(entry)).to be_falsey
    end

    it 'returns true if entry has an archive' do
      entry.attachments.create(attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE)
      entry.save!
      expect(described_class.archive?(entry)).to be_truthy
    end
  end

  describe 'generate_packets' do
    let!(:company) { create(:company) }
    let!(:entry) { create(:entry, importer: company, entry_number: 'ABCDEFG') }
    let!(:user) { create(:admin_user) }

    it 'runs the EntryAttachmentStitchRequestComparator for matching entries' do
      entry_attachment_comparator = OpenChain::CustomHandler::Vandegrift::EntryAttachmentStitchRequestComparator.new
      csv_file = "#{entry.entry_number}\r\n"
      settings = {}
      settings[:company_id] = company.id
      settings[:csv_file] = csv_file
      settings[:user_id] = user.id

      expect(OpenChain::CustomHandler::Vandegrift::EntryAttachmentStitchRequestComparator).to receive(:new)
        .and_return(entry_attachment_comparator)

      expect(entry_attachment_comparator).to receive(:generate_and_send_stitch_request)
        .with(entry, entry_attachment_comparator.attachment_archive_setup_for(entry))

      described_class.generate_packets(settings)
    end
  end

  describe 'parse_csv' do
    it 'returns nil if no csv_file is present' do
      expect(described_class.parse_csv('')).to be_nil
    end

    it 'returns an array of entry numbers if given a csv file' do
      csv_file = "a\r\nb\r\nc\r\n"
      expect(described_class.parse_csv(csv_file)).to eql(['a', 'b', 'c'])
    end
  end
end
