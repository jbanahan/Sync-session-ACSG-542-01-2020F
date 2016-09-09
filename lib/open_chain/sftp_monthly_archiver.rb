require 'open_chain/ftp_file_support'
require 'zip'
require 'zip/filesystem'

module OpenChain
  class SftpMonthlyArchiver
    include OpenChain::FtpFileSupport

    def self.run_schedulable(opts={})
      self.new(opts).run
    end

    def initialize(settings)
      raise "Alliance Customer Number Required" unless settings['alliance_customer_number'].present?
      raise "FTP Folder Required" unless settings['ftp_folder'].present?
      @company = Company.find_by_alliance_customer_number settings['alliance_customer_number']
      @settings = settings
    end

    def run
      mm_yyyy = Time.zone.now.strftime("%Y-%m")
      aas = @company.attachment_archive_setup
      raise "No Attachment Archive Setup exists for #{@company.alliance_customer_number}." unless aas

      counter = 0
      aas.broker_reference_override = @settings['broker_reference_override'] if @settings['broker_reference_override'].present?

      while aas.entry_attachments_available?
        file_name = "#{@company.alliance_customer_number}-#{mm_yyyy}"
        file_name << "(#{counter})" if counter > 0
        file_name << ".zip"

        archive = aas.create_entry_archive! file_name, 682.megabytes
        send_zip(archive)
        archive.finish_at = Time.zone.now
        archive.save

        counter += 1
      end
    end

    def send_zip(archive)
      begin
        Tempfile.open(@settings['alliance_customer_number']) do |f|
          Zip::File.open(f.path, Zip::File::CREATE) do |zipfile|
            archive.attachment_archives_attachments.each do |archive_attachment|
              attachment = archive_attachment.attachment
              next if attachment.nil?

              io = StringIO.new
              OpenChain::S3.get_data(attachment.bucket, attachment.path, io)
              zipfile.file.open(archive_attachment.output_path, "w") { |f| f << io.read }
            end

            manifest = archive.company.attachment_archive_manifests.build.generate_manifest_tempfile! 1.year.ago
            begin
              zipfile.file.open("ArchiveManifest-#{Time.zone.now.strftime("%Y-%m-%d")}.xls", "w") { |f| f << manifest.read }
            ensure
              manifest.close!
            end
          end

          ftp_file f, connect_vfitrack_net(@settings['ftp_folder'], archive.name)

          if @settings['notification_email'].present?
            OpenMailer.send_simple_html(@settings['notification_email'],
                                        "Attachment Archive #{archive.name} Uploaded",
                                        "An attachment archive named #{archive.name} is being sent to you.  You should receive it shortly.").deliver
          end
        end
      rescue => e
        e.log_me
      end
    end
  end
end
