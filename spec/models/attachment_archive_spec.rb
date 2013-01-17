describe 'spec_helper'

describe AttachmentArchive do
  describe :attachment_list_json do
    it "should write entry information" do
      entry = Factory(:entry,:arrival_date=>1.day.ago,:importer=>Factory(:company))
      attachment = entry.attachments.create!(:attached_file_name=>'a.txt',:attached_file_size=>100,:attachment_type=>'EDOC')
      arch = entry.importer.create_attachment_archive_setup(:start_date=>1.year.ago).create_entry_archive! "my arch", 100.megabytes
      r = JSON.parse arch.attachment_list_json
      aa = r['attachment_archive']
      aa['name'].should == 'my arch'
      aa['attachment_archives_attachments'].should have(1).element
      aaa = aa['attachment_archives_attachments'].first
      aaa['file_name'].should == "#{attachment.id}-a.txt"
      att = aaa['attachment']
      att['id'].should == attachment.id
      att['attached_file_name'].should == 'a.txt'
      ent = att['attachable']
      aa['more_files?'].should == false
    end
  end
end
