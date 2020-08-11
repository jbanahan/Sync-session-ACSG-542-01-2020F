describe OpenChain::CustomHandler::Target::TargetEntryZipFileParser do

  let(:log) { InboundFile.new }

  before do
    allow(subject).to receive(:inbound_file).and_return log
  end

  describe "include_file?" do
    it "includes PDF files only" do
      stub_const('ZipEntry', Struct.new(:name))
      expect(subject.include_file?(ZipEntry.new("a.pdf"))).to eq true
      expect(subject.include_file?(ZipEntry.new("b.PDF"))).to eq true
      expect(subject.include_file?(ZipEntry.new("a.html"))).to eq false
      expect(subject.include_file?(ZipEntry.new("no_extension"))).to eq false
    end
  end

  describe "handle_empty_file" do
    it "logs a reject message and sends an email" do
      Factory(:mailing_list, system_code: "target_pdf_errors", email_addresses: "a@b.com, c@d.com")

      subject.handle_empty_file "some_file_678.zip", nil

      expect(log).to have_reject_message("Zip file contained no PDF files.")

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq "Empty Target Zip - some_file_678.zip"
      expect(mail.body).to include "The zip file named some_file_678.zip contains no PDF files."
    end

    it "raises an error when the mailing list is not found" do
      expect { subject.handle_empty_file("some_file_678.zip", nil) }.to raise_error "Target PDF Errors mailing list not configured."

      expect(log).to have_error_message("Target PDF Errors mailing list not configured.")
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end
  end

  describe "process_file" do
    let(:zip_file) { File.open("spec/fixtures/files/Long_Beach_YMLU_W490374363_20200727072010.zip", "rb") }

    it "combines all PDFs from a zip file" do
      # This entry shouldn't be chosen because it doesn't belong to Target.
      Factory(:entry, customer_number: "ARGENT", source_system: Entry::KEWILL_SOURCE_SYSTEM, broker_reference: "ENT28856",
                      master_bills_of_lading: "YMLUW490374363", file_logged_date: Date.new(2019, 8, 1))
      # This entry shouldn't be chosen because it doesn't come from the Alliance system.
      Factory(:entry, customer_number: "TARGEN", source_system: Entry::FENIX_SOURCE_SYSTEM, broker_reference: "ENT28857",
                      master_bills_of_lading: "YMLUW490374363", file_logged_date: Date.new(2019, 8, 2))
      # This entry is the one that we should be matching to.
      entry = Factory(:entry, customer_number: "TARGEN", source_system: Entry::KEWILL_SOURCE_SYSTEM, broker_reference: "ENT28858",
                              master_bills_of_lading: "YMLUW490374362\n YMLUW490374363", file_logged_date: Date.new(2019, 7, 31))
      # The newer entry should be chosen, not this one, although this entry matches the look-up criteria.
      Factory(:entry, customer_number: "TARGEN", source_system: Entry::KEWILL_SOURCE_SYSTEM, broker_reference: "ENT28855",
                      master_bills_of_lading: "YMLUW490374363", file_logged_date: Date.new(2019, 4, 4))

      # This verifies that we're not trying to include the html file in this zip, only the PDFs.
      zip_content_arr = ["Bill of Lading-3752035-BL W490374363.pdf",
                         "Commercial Invoice-3752035-CI_3752035_SGN4425991_CFS.pdf",
                         "Forwarders cargo receipt-3752035-FCR VNTRIPLE_USTARGETST_SGN3216506_C.pdf",
                         "Packing List-3752035-PL_3752035_SGN4425991_CFS.pdf"]
      expect(subject).to receive(:process_zip_content).with("Long_Beach_YMLU_W490374363_20200727072010.zip", match_property(zip_content_arr, :name),
                                                            zip_file, "the_bucket",
                                                            "Long_Beach_YMLU_W490374363_20200727072010.20200727072010.zip", 1).and_call_original

      # This has the packing list sorted before the "Forwarders cargo receipt" document, verifying that we are stitching
      # the docs together in the proper order.
      sorted_zip_arr = ["Bill of Lading-3752035-BL W490374363.pdf",
                        "Commercial Invoice-3752035-CI_3752035_SGN4425991_CFS.pdf",
                        "Packing List-3752035-PL_3752035_SGN4425991_CFS.pdf",
                        "Forwarders cargo receipt-3752035-FCR VNTRIPLE_USTARGETST_SGN3216506_C.pdf"]
      expect(subject).to receive(:combine_pdfs).with(match_property(sorted_zip_arr, :name),
                                                     "Long_Beach_YMLU_W490374363_20200727072010.zip", zip_file).and_call_original

      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).to receive(:send_entry_packet_to_s3).with(entry, instance_of(Tempfile))

      Timecop.freeze(Date.new(2019, 8, 4)) do
        expect(subject.process_file(zip_file, "the_bucket", "Long_Beach_YMLU_W490374363_20200727072010.20200727072010.zip", 1)).to be_nil
      end

      expect(log).to have_identifier(:master_bill, "YMLUW490374363", "Entry", entry.id)
      expect(log).to have_info_message("4 PDF files were merged.")
      expect(log).to have_info_message("Entry doc packet was dropped into the CMUS pickup folder.")
    end

    it "sends email if matching entry cannot be found" do
      # This entry matches everything it needs to match, but the file logged date is too far in the past to be returned.
      Factory(:entry, customer_number: "TARGEN", source_system: Entry::FENIX_SOURCE_SYSTEM, broker_reference: "ENT28857",
                      master_bills_of_lading: "YMLUW490374363", file_logged_date: Date.new(2019, 2, 15))

      Factory(:mailing_list, system_code: "target_pdf_errors", email_addresses: "a@b.com, c@d.com")

      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).not_to receive(:send_entry_packet_to_s3)

      Timecop.freeze(Date.new(2019, 8, 4)) do
        expect(subject.process_file(zip_file, "the_bucket", "Long_Beach_YMLU_W490374363_20200727072010.zip", 1)).to be_nil
      end

      expect(log).to have_identifier(:master_bill, "YMLUW490374363")
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_INFO).length).to eq 0

      expect(log).to have_reject_message("A matching entry could not be found for master bill YMLUW490374363.")

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq "Target Zip Error - Entry YMLUW490374363 Not Found - Action Required"
      expect(mail.body).to include "A matching entry could not be found for master bill YMLUW490374363.  " +
                                   "The attached zip file could not be processed automatically.  " +
                                   "Files will need to uploaded manually to CMUS."
    end

    it "sends email if filename format is abnormal" do
      Factory(:mailing_list, system_code: "target_pdf_errors", email_addresses: "a@b.com, c@d.com")

      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).not_to receive(:send_entry_packet_to_s3)

      expect(subject.process_file(zip_file, "the_bucket", "LongBeach_20200727072010.zip", 1)).to be_nil

      expect(log).not_to have_identifier(:master_bill)
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_INFO).length).to eq 0

      expect(log).to have_reject_message("The master bill of lading could not be determined from the name of the zip file.")

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq "Problem Target Zip Name - LongBeach_20200727072010.zip - Action Required"
      expect(mail.body).to include "The master bill of lading could not be determined from the name of the attached " +
                                   "zip file.  It could not be processed automatically.  Files will need to " +
                                   "uploaded manually to CMUS."
    end

    it "raises error if mailing list not configured when there's an abnormal filename format issue" do
      expect { subject.process_file(zip_file, "the_bucket", "LongBeach_20200727072010.zip", 1) }.to raise_error "Target PDF Errors mailing list not configured."

      expect(log).to have_reject_message("The master bill of lading could not be determined from the name of the zip file.")
      expect(log).to have_error_message("Target PDF Errors mailing list not configured.")
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "handles a zip-stitching error" do
      Factory(:entry, customer_number: "TARGEN", source_system: Entry::KEWILL_SOURCE_SYSTEM, broker_reference: "ENT28858",
                      master_bills_of_lading: "YMLUW490374363", file_logged_date: Date.new(2019, 7, 31))
      Factory(:mailing_list, system_code: "target_pdf_errors", email_addresses: "a@b.com, c@d.com")

      expect(subject).to receive(:add_pdf_to_entry_packet).and_raise "Stitching error"

      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).not_to receive(:send_entry_packet_to_s3)

      Timecop.freeze(Date.new(2019, 8, 4)) do
        expect(subject.process_file(zip_file, "the_bucket", "Long_Beach_YMLU_W490374363_20200727072010.20200727072010.zip", 1)).to be_nil
      end

      expect(log).to have_identifier(:master_bill, "YMLUW490374363")
      expect(log).to have_error_message("The PDF files could not be stitched together.")
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_INFO).length).to eq 0

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["a@b.com", "c@d.com"]
      expect(mail.subject).to eq "Bad Target PDF - Long_Beach_YMLU_W490374363_20200727072010.zip - Action Required"
      expect(mail.body).to include "The attached zip file could not be processed automatically.  Files will need to uploaded manually to CMUS."
    end

    it "raises error if mailing list not configured when there's a zip-stitching error" do
      Factory(:entry, customer_number: "TARGEN", source_system: Entry::KEWILL_SOURCE_SYSTEM, broker_reference: "ENT28858",
                      master_bills_of_lading: "YMLUW490374363", file_logged_date: Date.new(2019, 7, 31))

      expect(subject).to receive(:add_pdf_to_entry_packet).and_raise "Stitching error"

      error_msg = "Target PDF Errors mailing list not configured."
      Timecop.freeze(Date.new(2019, 8, 4)) do
        expect { subject.process_file(zip_file, "the_bucket", "Long_Beach_YMLU_W490374363_20200727072010.zip", 1) }.to raise_error error_msg
      end

      expect(log).to have_error_message("The PDF files could not be stitched together.")
      expect(log).to have_error_message("Target PDF Errors mailing list not configured.")
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end
  end

end