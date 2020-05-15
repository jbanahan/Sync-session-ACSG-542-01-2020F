module OpenChain; class ArchivePacketGenerator
  def self.generate_packets(settings)
    user = User.find(settings[:user_id])
    company = Company.find(settings[:company_id])

    if settings[:start_date].blank? && settings[:csv_file].blank?
      subject = "Archive Packet Generation Failed"
      body = "Your archive packet generation request failed because a start date or csv file is required"
      user.messages.create(subject: subject, body: body)
    end

    entry_numbers = parse_csv(settings[:csv_file])
    start_date = settings[:start_date]
    end_date = settings[:end_date]
    c = OpenChain::CustomHandler::Vandegrift::EntryAttachmentStitchRequestComparator.new

    query = Entry.where(importer_id: company.id)
    query = query.where(["last_billed_date >= ?", start_date]) if start_date.present?
    query = query.where(["last_billed_date < ?", end_date]) if end_date.present?
    query = query.where(entry_number: entry_numbers) if entry_numbers.present?
    query.find_each do |entry|
      next if archive?(entry)

      c.generate_and_send_stitch_request(entry, c.attachment_archive_setup_for(entry))
    end

    subject = 'Archive packet successfully created'
    body = 'Your archive packet request has completed successfully.'
    user.messages.create(subject: subject, body: body)
  end

  def self.archive?(entry)
    attachment_types = entry.attachments.pluck(:attachment_type)

    attachment_types.include?(Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE)
  end

  def self.parse_csv(csv_file)
    return nil if csv_file.blank?

    entry_numbers = []

    CSV.parse(csv_file) do |row|
      entry_numbers << row
    end

    entry_numbers.flatten
  end
end; end