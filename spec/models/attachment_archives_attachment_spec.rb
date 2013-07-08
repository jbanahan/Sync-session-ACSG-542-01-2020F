describe 'spec_helper'

describe AttachmentArchivesAttachment do
  context :output_path do
    it "should use the attached entry to generate a path based on the broker reference number" do
      entry = Factory(:entry,:arrival_date=>1.day.ago,:importer=>Factory(:company), :broker_reference=>'brokerref')
      invoice = Factory(:broker_invoice, :entry=>entry, :invoice_date=>2.months.ago)
      attachment = entry.attachments.create!(:attached_file_name=>'a.txt',:attached_file_size=>100,:attachment_type=>'EDOC')
      arch = entry.importer.create_attachment_archive_setup(:start_date=>1.year.ago).create_entry_archive! "my arch", 100.megabytes

      aaa = arch.attachment_archives_attachments.first

      aaa.output_path.should == "#{entry.broker_reference}/#{aaa.file_name}"
    end
  end
end