describe 'spec_helper'

describe AttachmentArchive do
  describe :attachment_list_json do
    it "should write entry information" do
      entry = Factory(:entry,:arrival_date=>1.day.ago,:importer=>Factory(:company), :broker_reference=>'brokerref')
      invoice = Factory(:broker_invoice, :entry=>entry, :invoice_date=>2.months.ago)
      attachment = entry.attachments.create!(:attached_file_name=>'a.txt',:attached_file_size=>100,:attachment_type=>'EDOC')
      arch = entry.importer.create_attachment_archive_setup(:start_date=>1.year.ago).create_entry_archive! "my arch", 100.megabytes
      r = JSON.parse arch.attachment_list_json
      aa = r['attachment_archive']
      expect(aa['name']).to eq('my arch')
      expect(aa['attachment_archives_attachments'].size).to eq(1)
      aaa = aa['attachment_archives_attachments'].first
      expect(aaa['file_name']).to eq("EDOC-#{attachment.id}-a.txt")
      expect(aaa['output_path']).to eq(arch.attachment_archives_attachments.first.output_path)

      att = aaa['attachment']
      expect(att['id']).to eq(attachment.id)
      expect(att['attached_file_name']).to eq('a.txt')
    end
  end
end
