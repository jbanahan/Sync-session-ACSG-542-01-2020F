require 'open_chain/ftp_file_support'
require 'open_chain/polling_job'
require 'open_chain/s3'

module OpenChain; class TariffFileMonitor
  include OpenChain::FtpFileSupport
  include OpenChain::PollingJob

  def self.run_schedulable opts
    opts = opts.with_indifferent_access
    self.new.run opts
  end

  def run opts
    validate_opts opts
    adjust_email_to(opts)

    errors = []
    processed_files = []

    poll do |last_pickup, current_runtime|
      open_ftp_connection(opts[:protocol], opts[:hostname], opts[:port], opts[:username], opts[:password]) do |client|
        subdirectories = get_updated_subdirectories client, opts[:directory], last_pickup
        subdirectories.each do |subdir|
          files = get_unprocessed_file_list client, opts[:directory], subdir.name, last_pickup
          files.each do |f|
            file_name = f.name.upcase

            processed = false
            download_file(f, client) do |def_file|
              # The first two characters in filenames should be a country code.  Generally speaking, this is the ISO
              # 3166-1 alpha code, but there are some exceptions: Chinese 13-digit tariff files come with a code of "C9",
              # for example, and we get "EU" for the European Union, which covers multiple countries.
              country_code = file_name[0..1].upcase
              tariff_def = TariffFileUploadDefinition.where(country_code:country_code).first
              if tariff_def
                # Check to see if the file name matches the format regular expression from the definition.  This is meant
                # to screen out problem files (e.g. we get two types of files for the US: one we want, and another
                # we don't).  This could be added or moved to instance-level if it ever turns out that files need to be
                # handled included/excluded per instance.  That hasn't been the case to date.
                if Regexp.new(tariff_def.filename_regex).match(file_name)
                  tariff_def.tariff_file_upload_instances.each do |instance|
                    # Make a copy of the downloaded file.  This step is dumb, but necessary when dealing with multiple
                    # instances (e.g. trying to send the file to 2+ locations) because the FTP send process closes the
                    # stream.  FtpFileSupport can be told to not delete the file, but having its stream closed seems to
                    # be unavoidable.  (Since this is a one-off tempfile, we're letting FtpFileSupport delete it.)
                    Tempfile.open(["tariff_upload", ".zip"]) do |def_file_copy|
                      IO.copy_stream(def_file, def_file_copy)
                      Attachment.add_original_filename_method def_file_copy, get_country_appropriate_file_name(f.name, tariff_def, instance)
                      ftp_file def_file_copy, ecs_connect_vfitrack_net("#{instance.vfi_track_system_code}/tariff_file")

                      def_file.rewind
                    end

                    instance.tariff_file_upload_receipts.build([filename:f.name])
                    instance.save!

                    processed = true
                  end

                  # Archive the file to S3.  We're not actually doing anything with it there any longer; we're just keeping
                  # the tariff files stored in S3 for the sake of historical consistency and backup.
                  if processed
                    Attachment.add_original_filename_method def_file, get_country_appropriate_file_name(f.name, tariff_def)
                    OpenChain::S3.upload_file OpenChain::S3.bucket_name, "production/TariffStore/#{get_country_appropriate_file_name(f.name, tariff_def)}", def_file
                  end
                else
                  errors << "Tariff file received for country code '#{country_code}' did not match the file naming standard: #{f.name}."
                end
              else
                errors << "Tariff file received for country code '#{country_code}': #{f.name}.  Nothing has been set up for this country."
              end
            end

            if processed
              processed_files << f.name
            end
          end
        end
      end
    end

    if errors.length > 0
      send_error_email opts[:email_to], errors
    end

    if processed_files.length > 0
      send_success_email opts[:email_to], processed_files
    end
  end

  private
    def validate_opts opts
      raise ArgumentError, "'protocol', 'hostname', 'username', 'password', and 'directory' are all required." if [:protocol, :hostname, :username, :password, :directory].any? {|k| opts[k].blank? }
      raise ArgumentError, "One of 'email_to' or 'mailing_list' is required." if opts[:email_to].blank? && opts[:mailing_list].blank?
    end

    def adjust_email_to opts
      if opts[:mailing_list]
        list = MailingList.where(system_code: opts[:mailing_list]).first
        raise ArgumentError, "No Mailing List found with system code '#{opts[:mailing_list]}'." if list.nil?
        opts[:email_to] = list
      end
    end

    def get_last_pickup key
      last_pickup_val = key.data['last_pickup']

      time_zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      now = time_zone.now
      if last_pickup_val.nil?
        # Default to the current date/time if there's no prior record of this running before.  We're presuming that we're
        # to be starting from a clean slate, that any files in the directory already are ones that
        last_pickup = now
      else
        # Turn the json data into an actual date object.
        last_pickup = time_zone.parse last_pickup_val
      end
      [last_pickup, now]
    end

    def open_ftp_connection protocol, hostname, port, username, password
      opts = {}
      opts[:port] = port unless port.blank?
      ftp_client(protocol).connect(hostname, username, password, "", opts) do |client|
        yield client
      end
    end

    def ftp_client protocol
      if protocol.to_s.upcase.strip == "FTP"
        return FtpSender::FtpClient.new
      else
        return FtpSender::SftpClient.new
      end
    end

    # Finds all the subdirectories under the base directory that have had tariff files added since the last pickup date.
    def get_updated_subdirectories client, directory, last_pickup
      client.chdir(directory)
      client.list_files(include_only_files:false).select { |f| f.mtime > last_pickup && f.directory? }
    end

    # Looks for files in the provided directory/subdirectory combo that have been added since the last pickup date.
    # Filters out non-zip files (rare) and files that include the phrase "_changes" in their names (very common -
    # every updated set of tariff definitions typically comes with a change-file).  We need the full tariff lists here,
    # not the breakdown of what changed.
    def get_unprocessed_file_list client, directory, subdir, last_pickup
      client.chdir("#{directory}/#{subdir}")
      client.list_files.select { |f| f.mtime > last_pickup && /\.ZIP$/.match(f.name.upcase) && !/_CHANGES/.match(f.name.upcase) }
    end

    # Downloads the tariff definition zip file from the customsinfo FTP site to a tempfile, which is purged
    def download_file ftp_file, client
      Tempfile.open(["tariff_upload", ".zip"]) do |tmp|
        client.get_binary_file(ftp_file.name, tmp.path)
        yield tmp
      end
    end

    # TariffLoader uses the first two characters of the filename to establish the country that needs to have its
    # tariffs uploaded.  Because the first two characters in some filenames don't actually represent an ISO code
    # (e.g. Chinese 13-digit tariff files begin with a code of "C9", and an "EU" code is used to cover multiple
    # European Union countries), we have to prepend those to the filename for the copies of the file exported to the
    # assorted VFI Track instances.  Alternate codes can come from either the tariff upload definition or the
    # tariff upload instance records, with instance trumping definition in the event both have values.  If neither one
    # of those fields has a value, this method returns base_file_name as is.
    def get_country_appropriate_file_name base_file_name, tariff_def, instance=nil
      if instance && instance.country_iso_alias
        file_name = "#{instance.country_iso_alias}_#{base_file_name}"
      elsif tariff_def.country_iso_alias
        file_name = "#{tariff_def.country_iso_alias}_#{base_file_name}"
      else
        file_name = base_file_name
      end
      file_name
    end

    def send_error_email email_to, errors
      body = "<p>Errors were encountered while processing tariff files.</p><ol>"
      errors.uniq.each do |msg|
        body += "<li>#{msg}</li>"
      end
      body += "</ol>"

      email_subject = "Tariff File Monitor Errors"

      OpenMailer::send_simple_html(email_to, email_subject, body.html_safe).deliver!
    end

    def send_success_email email_to, report_files
      body = "<p>#{report_files.length} #{"file".pluralize(report_files.length)} #{report_files.length > 1 ? "were" : "was"} processed from the pickup directory.</p><ol>"
      report_files.each do |file_name|
        body += "<li>#{file_name}</li>"
      end
      body += "</ol>"

      email_subject = "Tariff File Monitor Update"

      OpenMailer::send_simple_html(email_to, email_subject, body.html_safe).deliver!
    end

end; end;