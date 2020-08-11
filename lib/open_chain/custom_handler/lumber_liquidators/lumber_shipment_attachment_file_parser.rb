require 'open_chain/custom_handler/zip_file_parser'
require 'open_chain/integration_client_parser'

# Works with a zip file, attaching the PDF contents of that zip to a matching shipment by matching the
# master bill in the zip file's name to shipment's master bill.  Handles cases where the shipment doesn't
# yet exist.
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberShipmentAttachmentFileParser < OpenChain::CustomHandler::ZipFileParser

  def process_zip_content original_zip_file_name, unzipped_contents, _zip_file, s3_bucket, s3_key, attempt_count
    # If we've made it this far, we know that there is at least one PDF within the zip.  Per project assumptions,
    # there's only supposed to be one.  If not, any beyond the first get ignored.
    zip_content_pdf = unzipped_contents[0]
    master_bill = parse_master_bill original_zip_file_name
    shp = Shipment.where(master_bill_of_lading: master_bill).first
    if shp.present?
      inbound_file.add_identifier InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, shp.reference
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
    nil
  end

  def include_file? zip_entry
    File.extname(zip_entry.name).to_s.upcase == ".PDF"
  end

  def handle_empty_file zip_file_name, zip_file
    generate_missing_pdf_email parse_master_bill(zip_file_name), zip_file
  end

  private
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
      write_zip_entry_to_temp_file(zip_content_pdf, attachment_file_name(s3_path)) do |temp_file|
        Lock.with_lock_retry(shp) do
          shp.attachments.create!(attached:temp_file, attachment_type:'ODS-Forwarder Ocean Document Set')
          # Including the S3 path allows for the original zip file to be downloaded from history. (Note that this process
          # does not include the S3 bucket: it assumes all incoming files will go through the same integration bucket.)
          shp.create_snapshot User.integration, nil, s3_path
        end
      end
    end

    def attachment_file_name s3_path
      "#{File.basename(original_file_name(s3_path), ".*")}.pdf"
    end

    def requeue_file_for_later_processing s3_bucket, s3_key, attempt_count
      next_run_time = Time.zone.now + 1.hour
      OpenChain::CustomHandler::LumberLiquidators::LumberShipmentAttachmentFileParser.delay(run_at: next_run_time).process_from_s3 s3_bucket, s3_key, {attempt_count:(attempt_count + 1)}
    end

    def generate_missing_shipment_email master_bill, zip_content_pdf, s3_path
      write_zip_entry_to_temp_file(zip_content_pdf, attachment_file_name(s3_path)) do |temp_file|
        body_text = "VFI Track has tried for 4 days to find a shipment matching master bill '#{master_bill}' without success.  No further attempts will be made.  Allport document attachments (ODS) are available for this shipment.  VFI operations will be required to manually upload vendor docs (VDS) and shipment docs (ODS) manually."
        OpenMailer.send_simple_html('LL-US@vandegriftinc.com', "Allport Missing Shipment: #{master_bill}", body_text, [temp_file]).deliver_now
      end
    end

    def generate_missing_pdf_email master_bill, zip_file
      body_text = "The attached zip file for master bill '#{master_bill}', received on #{Time.now.strftime("%d/%m/%Y")}, is invalid or does not contain a PDF file.  Contact Lumber and Allport for resolution."
      mailing_list = MailingList.where(system_code:'ODSNotifications').first
      raise "Allport ODS Notifications mailing list not configured." unless mailing_list
      OpenMailer.send_simple_html([mailing_list], 'Allport ODS docs not in zip file', body_text, [zip_file], { reply_to:'ll-support@vandegriftinc.com' }).deliver_now
    end

end; end; end; end