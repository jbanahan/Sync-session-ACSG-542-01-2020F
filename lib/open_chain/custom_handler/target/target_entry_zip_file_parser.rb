require 'open_chain/custom_handler/zip_file_parser'
require 'combine_pdf'

# Combines the PDF contents of a zip file into a single PDF, which is matched to an entry and then sent to CMUS.
# Handles cases where the entry doesn't yet exist.
module OpenChain; module CustomHandler; module Target; class TargetEntryZipFileParser < OpenChain::CustomHandler::ZipFileParser

  def process_zip_content original_zip_file_name, unzipped_contents, zip_file, _s3_bucket, _s3_key, _attempt_count
    master_bill = parse_master_bill original_zip_file_name
    if master_bill.present?
      inbound_file.add_identifier(:master_bill, master_bill)

      # Find the entry that matches this master bill.  We'll need the entry for its broker ref, but, just as
      # importantly, KewillEntryDocumentSender will not send the doc pack to CMUS unless the entry is found.
      # Catching a missing entry or botched filename here allows us to reject/notify early in the process.
      entry = Entry.where(customer_number: "TARGEN", source_system: Entry::KEWILL_SOURCE_SYSTEM)
                   .where("master_bills_of_lading LIKE ?", "%#{master_bill}%")
                   .where("file_logged_date >= ? OR file_logged_date IS NULL", Time.zone.now - 6.months)
                   .order(:file_logged_date).last

      if entry
        inbound_file.set_identifier_module_info :master_bill, "Entry", entry.id

        # Sort the PDFs into the order they're supposed to appear in the combo-PDF.  Involving an array in the sort
        # allows for the items to be sorted first by a sequence number (meant to guarantee position for some files),
        # then alphabetically by name.
        unzipped_contents.sort_by! { |f| [file_sequence(f.name), f.name] }

        entry_packet_pdf = combine_pdfs unzipped_contents, original_zip_file_name, zip_file

        if entry_packet_pdf
          send_doc_packet entry, entry_packet_pdf
        end
      else
        inbound_file.add_reject_message "A matching entry could not be found for master bill #{master_bill}."
        generate_entry_not_found_email master_bill, zip_file
      end
    else
      inbound_file.add_reject_message "The master bill of lading could not be determined from the name of the zip file."
      generate_malformed_filename_email original_zip_file_name, zip_file
    end
    nil
  end

  def include_file? zip_entry
    File.extname(zip_entry.name).to_s.upcase == ".PDF"
  end

  def handle_empty_file zip_file_name, _zip_file
    inbound_file.add_reject_message "Zip file contained no PDF files."
    generate_missing_pdf_email zip_file_name
  end

  private

    def combine_pdfs unzipped_contents, original_file_name, zip_file
      entry_packet_pdf = CombinePDF.new
      begin
        unzipped_contents.each do |f|
          add_pdf_to_entry_packet f, entry_packet_pdf
        end
        inbound_file.add_info_message "#{unzipped_contents.length} PDF files were merged."
      # When we eventually upgrade the CombinePDF gem version, this rescue can look for CombinePDF::ParsingError.
      # It's, unfortunately, just a RuntimeError in the old version of gem currently in use.
      rescue StandardError
        inbound_file.add_error_message "The PDF files could not be stitched together."
        generate_malformed_pdf_email original_file_name, zip_file
        # Nil out the PDF object so we don't try to add an empty packet to the entry.
        entry_packet_pdf = nil
      end

      entry_packet_pdf
    end

    # Custom sort-ordering for the files within the combo-PDF.
    def file_sequence file_name
      file_name = file_name.upcase
      if file_name.starts_with? "BILL OF LADING-"
        so = 0
      elsif file_name.starts_with? "COMMERCIAL INVOICE-"
        so = 1
      elsif file_name.starts_with? "PACKING LIST-"
        so = 2
      else
        so = 3
      end
      so
    end

    def add_pdf_to_entry_packet pdf_zip_entry, entry_packet_pdf
      write_zip_entry_to_temp_file(pdf_zip_entry, pdf_zip_entry.name) do |pdf_temp_file|
        # Eat useless warning messages (e.g. "PDF 1.5 Object streams found - they are not fully supported!
        # attempting to extract objects.") to prevent them from filling up the log.
        Kernel.silence_warnings do
          entry_packet_pdf << CombinePDF.load(pdf_temp_file.path, allow_optional_content: true)
        end
      end
    end

    # The master bill value, sent after port name, contains an internal hyphen that needs to be stripped out.
    # Examples:
    #   Tacoma_EGLV_235000619065_20200727064433.zip -> EGLV235000619065
    #   Long_Beach_YMLU_W490374363_20200727072010.zip -> YMLUW490374363
    def parse_master_bill filename
      (filename.match('\w*_(\w*_\w*)_\d*.zip').presence || [])[1]&.gsub('_', '')
    end

    def generate_missing_pdf_email file_name
      body_text = "The zip file named #{file_name} contains no PDF files."
      OpenMailer.send_simple_html(pdf_errors_mailing_list, "Empty Target Zip - #{file_name}", body_text).deliver_now
    end

    def pdf_errors_mailing_list
      mailing_list = MailingList.where(system_code: "target_pdf_errors").first
      inbound_file.error_and_raise "Target PDF Errors mailing list not configured." unless mailing_list
      mailing_list
    end

    def generate_malformed_pdf_email file_name, zip_file
      body_text = "The attached zip file could not be processed automatically.  Files will need to uploaded manually to CMUS."
      OpenMailer.send_simple_html(pdf_errors_mailing_list, "Bad Target PDF - #{file_name} - Action Required",
                                  body_text, [zip_file]).deliver_now
    end

    def generate_malformed_filename_email file_name, zip_file
      body_text = "The master bill of lading could not be determined from the name of the attached zip file.  " +
                  "It could not be processed automatically.  Files will need to uploaded manually to CMUS."
      OpenMailer.send_simple_html(pdf_errors_mailing_list, "Problem Target Zip Name - #{file_name} - Action Required",
                                  body_text, [zip_file]).deliver_now
    end

    def generate_entry_not_found_email master_bill, zip_file
      body_text = "A matching entry could not be found for master bill #{master_bill}.  " +
                  "The attached zip file could not be processed automatically.  Files will need to uploaded manually to CMUS."
      OpenMailer.send_simple_html(pdf_errors_mailing_list, "Target Zip Error - Entry #{master_bill} Not Found - Action Required",
                                  body_text, [zip_file]).deliver_now
    end

    def send_doc_packet entry, entry_packet_pdf
      Tempfile.open('EntryPacket-TARGET.pdf') do |tmp|
        # Write the entry packet content to a tempfile.
        tmp.binmode
        entry_packet_pdf.save(tmp.path)

        # Send that file to the S3 pick-up folder, which the KewillEntryDocumentsSender scheduled job will poll.
        # The sender will deal with the complexities of sending the file to CMUS for us.
        OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender.send_entry_packet_to_s3 entry, tmp

        inbound_file.add_info_message "Entry doc packet was dropped into the CMUS pickup folder."
      end
    end

end; end; end; end