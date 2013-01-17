require 'spec_helper'

describe AttachmentArchiveSetup do
  before :each do
    @c = Factory(:company)
    @entry = Factory(:entry,:importer=>@c,:arrival_date=>1.month.ago)
    @setup = @c.create_attachment_archive_setup(:start_date=>1.year.ago)
    @att = @entry.attachments.create!(:attached_file_name=>'a.txt',:attached_file_size=>100)
    @att2 = @entry.attachments.create!(:attached_file_name=>'b.txt',:attached_file_size=>100)
  end
  describe "create_entry_archive!" do
    it "should include relevant attachments" do
      archive = @setup.create_entry_archive! "my name", 5.megabytes
      archive.should be_persisted
      archive.name.should == "my name"
      archive.company.should == @c
      archive.attachments.to_a.should == [@att,@att2]
    end
    it "should stop at max size" do
      @setup.create_entry_archive!("my name", 199).attachments.to_a.should == [@att]
    end
    it "should not include non-entry attachments" do
      att3 = Attachment.create!(:attached_file_name=>'no.txt',:attached_file_size=>1)
      @setup.create_entry_archive!("my name", 1000).attachments.to_a.should == [@att,@att2]
    end
    it "should not include attachments for other importers" do
      e2 = Factory(:entry)
      att3 = e2.attachments.create(:attached_file_name=>'c.txt',:attached_file_size=>1)
      @setup.create_entry_archive!("my name", 1000).attachments.to_a.should == [@att,@att2]
    end
    it "should not include attachments for entries arrived before start_date" do
      @setup.update_attributes(:start_date=>1.day.ago)
      @setup.create_entry_archive!("my name", 1000).attachments.count.should == 0
    end
    it "should not include attachments on another archive" do
      other_archive = AttachmentArchive.create!(:name=>'x',:company=>@c)
      other_archive.attachments << @att
      @setup.create_entry_archive!("my name", 1000).attachments.to_a.should == [@att2]
    end
  end
  describe "entry_attachments_available?" do
    it "should return true if unarchived attachments exist for company" do
      @setup.should be_entry_attachments_available
    end
    it "should return false if no unarchived attachments exist for company" do
      @setup.create_entry_archive! "name", 5.megabytes
      @setup.should_not be_entry_attachments_available
    end
  end
end
