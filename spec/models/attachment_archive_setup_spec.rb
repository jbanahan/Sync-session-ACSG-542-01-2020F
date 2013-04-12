require 'spec_helper'

describe AttachmentArchiveSetup do
  before :each do
    @c = Factory(:company)
    @entry = Factory(:entry,:importer=>@c,:arrival_date=>1.month.ago)
    @invoice = Factory(:broker_invoice, :entry => @entry, :invoice_date => (Time.current.midnight - 30.days) - 1.second)
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
      archive.should have(2).attachments
      archive.attachments.should include(@att,@att2)
    end
    it "should stop at max size" do
      # Because of the indeterminate ordering of the archive (attachments are only ordered by entry arrival date), 
      # just make sure 1 of the 2 attachments were included in the archive
      att = @setup.create_entry_archive!("my name", 199).attachments.to_a
      att.length.should == 1
      fail("Archive attachments should have included @att or @att2") unless att[0].id == @att.id || att[0].id == @att2.id
    end
    it "should not include non-entry attachments" do
      att3 = Attachment.create!(:attached_file_name=>'no.txt',:attached_file_size=>1)
      archive = @setup.create_entry_archive!("my name", 1000)
      archive.should have(2).attachments
      archive.attachments.should include(@att,@att2)
    end
    it "should not include attachments for other importers" do
      e2 = Factory(:entry)
      att3 = e2.attachments.create(:attached_file_name=>'c.txt',:attached_file_size=>1)
      archive = @setup.create_entry_archive!("my name", 1000)
      archive.should have(2).attachments
      archive.attachments.should include(@att,@att2)
    end
    it "should not include attachments invoiced before start_date" do
      @setup.update_attributes(:start_date=>Time.now)
      @setup.create_entry_archive!("my name", 1000).attachments.count.should == 0
    end
    it "should not include attachments invoiced less than 30 days ago" do
      @invoice.update_attributes(:invoice_date => Time.current.midnight - 29.days)
      @setup.create_entry_archive!("my name", 1000).attachments.count.should == 0
    end
    it "should include attachments that have one invoice newer than 30 days ago" do
      i2 = Factory(:broker_invoice, :entry=>@entry, :invoice_date => Time.current)
      @setup.create_entry_archive!("my name", 1000).attachments.count.should == 2
    end
    it "should include attachments only once" do
      # This is really just to verify distinct is being used
      i2 = Factory(:broker_invoice, :entry=>@entry, :invoice_date => 40.days.ago)
      @setup.create_entry_archive!("my name", 1000).attachments.count.should == 2
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
