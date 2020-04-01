describe AttachmentArchivesAttachment do
  context "output_path" do
    it "should use the attached entry to generate a path based on the broker reference number" do
      entry = Factory(:entry,:arrival_date=>1.day.ago,:importer=>Factory(:company), :broker_reference=>'brokerref',
        :po_numbers=>'1234567-25
 2345678-25
 3456789-25')
      invoice = Factory(:broker_invoice, :entry=>entry, :invoice_date=>2.months.ago)
      attachment = entry.attachments.create!(:attached_file_name=>'a.txt',:attached_file_size=>100,:attachment_type=>'EDOC')
      arch = entry.importer.create_attachment_archive_setup(:start_date=>1.year.ago).create_entry_archive! "my arch", 100.megabytes

      aaa = arch.attachment_archives_attachments.first

      expect(aaa.output_path).to eq("#{entry.broker_reference}/#{aaa.file_name}")
    end

    it "should use a custom output path if one is set in the attachment archive setup" do
      entry = Factory(:entry,:arrival_date=>1.day.ago,:importer=>Factory(:company), :broker_reference=>'brokerref',
        :entry_number=>'31605900732', :customer_references=>'60201
        60201A')
      invoice = Factory(:broker_invoice, :entry=>entry, :invoice_date=>2.months.ago)
      attachment = entry.attachments.create!(:attached_file_name=>'a.txt',:attached_file_size=>100,:attachment_type=>'EDOC')
      arch = entry.importer.create_attachment_archive_setup(:start_date=>1.year.ago,
        :output_path=>"{{entry.entry_number}}/{{entry.customer_references}}-{{attachment.attached_file_name}}").create_entry_archive! "my arch", 100.megabytes

      aaa = arch.attachment_archives_attachments.first

      expect(Attachment).to receive(:get_sanitized_filename).twice.and_call_original
      expect(aaa.output_path).to eq("31605900732/60201_ 60201A-a.txt")
    end
  end
end
