require 'open_chain/ftp_file_support'
require 'open_chain/zip_builder'

module OpenChain; class SftpMonthlyArchiver
  include OpenChain::FtpFileSupport

  def self.run_schedulable(opts = {})
    self.new(opts).run
  end

  def initialize(settings)
    if settings['alliance_customer_number'].blank? && settings['fenix_customer_number'].blank?
      raise "Alliance or Fenix Customer Number Required"
    end

    raise "FTP Folder Required" if settings['ftp_folder'].blank?

    @company = if settings['alliance_customer_number'].present?
                Company.with_customs_management_number(settings['alliance_customer_number']).first
               else
                Company.with_fenix_number(settings['fenix_customer_number']).first
               end

    @settings = settings
  end

  def run
    # As these archives are pretty much always going to represent data prior to this month, name this based
    # on the previous month.
    mm_yyyy = (Time.zone.now - 1.month).strftime("%Y-%m")
    aas = @company.attachment_archive_setup
    raise "No Attachment Archive Setup exists for #{@company.kewill_customer_number}." unless aas

    counter = 0
    aas.broker_reference_override = @settings['broker_reference_override'] if @settings['broker_reference_override'].present?

    while aas.entry_attachments_available?
      file_name = "#{@company.kewill_customer_number}-#{mm_yyyy}"
      file_name << " (#{counter + 1})" if counter > 0
      file_name << ".zip"

      archive = aas.create_entry_archive! file_name, 682.megabytes
      send_zip(archive)
      archive.finish_at = Time.zone.now
      archive.save

      counter += 1
    end
  end

  def send_zip(archive)
    OpenChain::ZipBuilder.create_zip_builder(archive.name) do |builder|
      zip_attachments(builder, archive)
      zip_manifest(builder, archive)

      # The zip file we're sending is going to be hundreds of MB large, we can't virus scan it without killing the machine
      # This is fine though, because the documents themselves have already been scanned as they came into the system via imaging.
      ftp_file builder.to_tempfile, connect_vfitrack_net(@settings['ftp_folder'], archive.name).merge({ skip_virus_scan: true })

      if @settings['notification_email'].present?
        OpenMailer.send_simple_html(@settings['notification_email'],
                                    "Attachment Archive #{archive.name} Uploaded",
                                    "An attachment archive named #{archive.name} is being sent to you.  You should receive it shortly.").deliver_now
      end
    end
  rescue StandardError => e
    e.log_me
  end

  def zip_attachments builder, archive
    archive.attachment_archives_attachments.each do |archive_attachment|
      attachment = archive_attachment.attachment
      next if attachment.nil?

      io = StringIO.new
      OpenChain::S3.get_data(attachment.bucket, attachment.path, io)
      io.rewind

      builder.add_file archive_attachment.output_path, io
    end
  end

  def zip_manifest builder, archive
    manifest = nil
    begin
      manifest = archive.company.attachment_archive_manifests.build.generate_manifest_tempfile! 1.year.ago
      builder.add_file "ArchiveManifest-#{Time.zone.now.strftime("%Y-%m-%d")}.xls", manifest
    ensure
      manifest&.close!
    end
  end

end; end
