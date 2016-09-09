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
      counter = 0
      aas.broker_reference_override = @settings['broker_reference_override'] if @settings['broker_reference_override'].present?

      while aas.entry_attachments_available?
        file_name = "#{@company.alliance_customer_number}-#{mm_yyyy}"
        file_name << "(#{counter})" if counter > 0
        file_name << ".zip"

        archive = aas.create_entry_archive! file_name, 682.megabytes
        send_zip(archive)

        counter += 1
      end
    end

    def send_zip(archive)
      begin
        Tempfile.open(@settings['alliance_customer_number']) do |f|
          Zip::File.open(f.path, Zip::File::CREATE) do |zipfile|
            archive.attachments.each do |attachment|
              io = StringIO.new
              OpenChain::S3.get_data(attachment.bucket, attachment.path, io)
              zipfile.file.open(attachment.unique_file_name, "w") { |f| f << io.read }
            end

            manifest = archive.company.attachment_archive_manifests.build.generate_manifest_tempfile! 1.year.ago
            zipfile.file.open('archive-manifest.xls', "w") { |f| f << manifest.read }
            manifest.close!
          end

          ftp_file f, connect_vfitrack_net(@settings['ftp_folder'], archive.name)
          archive.finish_at = Time.zone.now
          archive.save

          if @settings['notification_email'].present?
            OpenMailer.send_simple_html(@settings['notification_email'],
                                        "Attachment Archive #{archive.name} Uploaded",
                                        'Placeholder Text').deliver
          end
        end
      rescue => e
        e.log_me
      end
    end
  end
end
