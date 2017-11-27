require 'open_chain/integration_client_parser'
require 'combine_pdf'

# Works with a zip file, attaching the PDF contents of that zip to a matching shipment by matching the
# master bill in the zip file's name to shipment's master bill.  Handles cases where the shipment doesn't
# yet exist.
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberShipmentAttachmentFileParser
  extend OpenChain::IntegrationClientParser

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/ll/shipment_docs"
  end

  def self.process_from_s3 s3_bucket, s3_key, opts = {}
    OpenChain::S3.download_to_tempfile(s3_bucket, s3_key) do |tempfile|
      attempt_count = opts[:attempt_count].presence || 1
      self.new.process_file tempfile, s3_bucket, s3_key, attempt_count
    end
  end

  def process_file zip_file, s3_bucket, s3_key, attempt_count
    # The name/path of the zip file is not the original name of the file when it was FTP'ed by Lumber: the pick-up
    # routine attaches some other crud for the sake of uniqueness.  We can get that original name, however, from the
    # S3 key/path.
    original_zip_file_name = File.basename(self.class.get_s3_key_without_timestamp s3_key)
    master_bill = parse_master_bill original_zip_file_name
    zip_content_pdf = unzip_pdf zip_file
    if zip_content_pdf.present?
      shp = Shipment.where(master_bill_of_lading: master_bill).first
      if shp.present?
        process_zip_file_pdf zip_content_pdf, shp, original_zip_file_name, s3_key
      else
        # If no matching shipment is found, queue the file to be reprocessed an hour later, hoping the shipment has
        # been created. There is a limit to our patience with this: after 96 hours/attempts (4 days), we give up and
        # send an email.
        if attempt_count < 96
          requeue_file_for_later_processing s3_bucket, s3_key, attempt_count
        else
          generate_missing_shipment_email master_bill, zip_content_pdf, s3_key
        end
      end
    else
      generate_missing_pdf_email master_bill, zip_file
    end
  end

  private
    def unzip_pdf zip_file
      zip_content_pdf = nil
      begin
        Zip::File.open(zip_file.path) do |unzipped_zip_file|
          # Per assumptions, there's only supposed to be one file per zip, and it will be a PDF.
          unzipped_zip_file.each do |zip_entry|
            if File.extname(zip_entry.name).to_s.upcase == ".PDF"
              zip_content_pdf = zip_entry
              break
            end
          end
        end
      rescue Zip::Error
        # Do nothing.  Nil gets returned, which results in an error email.
      end
      zip_content_pdf
    end

    def process_zip_file_pdf zip_content_pdf, shp, original_zip_file_name, s3_path
      existing_ods_attachment = find_existing_ods_attachment shp

      version_number = parse_version_number original_zip_file_name
      version_number_existing = existing_ods_attachment.present? ? parse_version_number(existing_ods_attachment.attached_file_name) : nil
      # In the event we get a "stale" revision, where we've already got a later revision of this file (as based on the
      # version number baked into the filename) in the database, ignore the file and do nothing.  We're assuming that
      # updates to a file will come with a version increment as well, so the same version number received twice results
      # in no change either.
      if version_number_existing.nil? || version_number > version_number_existing
        if existing_ods_attachment.present?
          existing_ods_attachment.delete
        end
        create_shipment_attachment zip_content_pdf, shp, s3_path
      end
    end

    def parse_master_bill filename
      (filename.match('V\d+(\D\w+)\.').presence || [])[1]
    end

    def parse_version_number filename
      (filename.match('V(\d+)').presence || [])[1]
    end

    def find_existing_ods_attachment shp
      matching_attachment = nil
      pdf_attachments = shp.attachments.where(attachment_type:'ODS-Forwarder Ocean Document Set')
      pdf_attachments.each do |pdf|
        # Ensuring the master bill is part of the name of the found ODS-type attachment is probably unnecessary,
        # but doesn't hurt, as a safety precaution (since there's nothing stopping a person from using this type when
        # uploading other documents).  In a normal case, ODS would only be created via this parser, and would therefore
        # always contain master bill in the filename.
        if parse_master_bill(pdf.attached_file_name) == shp.master_bill_of_lading
          matching_attachment = pdf
        end
      end
      matching_attachment
    end

    def create_shipment_attachment zip_content_pdf, shp, s3_path
      write_pdf_zip_entry_to_temp_file(zip_content_pdf, s3_path) do |temp_file|
        Lock.with_lock_retry(shp) do
          shp.attachments.create!(attached:temp_file, attachment_type:'ODS-Forwarder Ocean Document Set')
          # Including the S3 path allows for the original zip file to be downloaded from history. (Note that this process
          # does not include the S3 bucket: it assumes all incoming files will go through the same integration bucket.)
          shp.create_snapshot User.integration, nil, s3_path
        end
      end
    end

    def write_pdf_zip_entry_to_temp_file zip_content_pdf, s3_path
      filename = File.basename(zip_content_pdf.name)
      Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |t|
        t.binmode
        t.write(zip_content_pdf.get_input_stream.read)
        t.flush
        t.rewind
        attachment_filename = "#{File.basename(self.class.get_s3_key_without_timestamp(s3_path), ".*")}.pdf"
        Attachment.add_original_filename_method t, attachment_filename
        yield t
      end
    end

    def requeue_file_for_later_processing s3_bucket, s3_key, attempt_count
      next_run_time = Time.zone.now + 1.hour
      OpenChain::CustomHandler::LumberLiquidators::LumberShipmentAttachmentFileParser.delay(run_at: next_run_time).process_from_s3 s3_bucket, s3_key, {attempt_count:(attempt_count + 1)}
    end

    def generate_missing_shipment_email master_bill, zip_content_pdf, s3_path
      write_pdf_zip_entry_to_temp_file(zip_content_pdf, s3_path) do |temp_file|
        body_text = "VFI Track has tried for 4 days to find a shipment matching master bill '#{master_bill}' without success.  No further attempts will be made.  Allport document attachments (ODS) are available for this shipment.  VFI operations will be required to manually upload vendor docs (VDS) and shipment docs (ODS) manually."
        OpenMailer.send_simple_html('LL-US@vandegriftinc.com', "Allport Missing Shipment: #{master_bill}", body_text, [temp_file]).deliver!
      end
    end

    def generate_missing_pdf_email master_bill, zip_file
      body_text = "The attached zip file for master bill '#{master_bill}', received on #{Time.now.strftime("%d/%m/%Y")}, is invalid or does not contain a PDF file.  Contact Lumber and Allport for resolution."
      OpenMailer.send_simple_html('support@vandegriftinc.com', 'Allport ODS docs not in zip file', body_text, [zip_file]).deliver!
    end

end; end; end; end