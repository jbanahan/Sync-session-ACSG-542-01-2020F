require 'spec_helper'

describe AttachmentArchiveSetup do
  before :each do
    @c = Factory(:company)
    @entry = Factory(:entry,:importer=>@c,:arrival_date=>1.month.ago)
    @invoice = Factory(:broker_invoice, :entry => @entry, :invoice_date => (Time.current.midnight - 30.days) - 1.second)
    @setup = @c.create_attachment_archive_setup(:start_date=>1.year.ago)
    @att = @entry.attachments.create!(:attached_file_name=>'a.pdf',:attached_file_size=>100)
    @att2 = @entry.attachments.create!(:attached_file_name=>'b.pdf',:attached_file_size=>100, is_private: false)
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
    it "should only include 'Archive Packet' attachments if there are any present on an entry" do
      @att3 = @entry.attachments.create! :attached_file_name=>'b.txt',:attached_file_size=>100, :attachment_type => Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
      expect(@setup.create_entry_archive!("my name", 1000).attachments.to_a).to eq [@att3]
    end
    it "should also include non-stitchable attachments if any 'Archive Packets' are on the entry " do
      @att3 = @entry.attachments.create! :attached_file_name=>'b.pdf',:attached_file_size=>100, :attachment_type => Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE
      @att.update_attributes! :attached_file_name => 'test.non-stitchable'

      att = @setup.create_entry_archive!("my name", 1000).attachments.to_a
      expect(att).to have(2).items
      expect(att).to include(@att3)
      expect(att).to include(@att)
    end
    it "includes invoices from last month when using 'previous month' archiving scheme" do
      @setup.update_attributes! archive_scheme: "PREVIOUS_MONTH"
      @invoice.update_attributes! invoice_date: Time.current.midnight.at_beginning_of_month - 1.day
      archive = @setup.create_entry_archive! "my name", 5.megabytes
      expect(archive).to have(2).attachments
      expect(archive.attachments).to include(@att,@att2)
    end
    it "excludes invoices from this month when using 'previous month' archiving scheme" do
      @setup.update_attributes! archive_scheme: "PREVIOUS_MONTH"
      @invoice.update_attributes! invoice_date: Time.current.midnight.at_beginning_of_month
      expect(@setup).not_to be_entry_attachments_available
    end
    it "excludes invoices that occur after the end date" do
      @setup.update_attributes! end_date: Date.new(2013, 1, 1)
      expect(@setup).not_to be_entry_attachments_available
    end
    it "excludes private attachments" do
      @att.update_attributes! is_private: true
      archive = @setup.create_entry_archive! "my name", 5.megabytes
      expect(archive.attachments).not_to include(@att)
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
