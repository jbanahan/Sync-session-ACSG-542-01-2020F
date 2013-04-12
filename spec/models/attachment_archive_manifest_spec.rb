require 'spec_helper'

describe AttachmentArchiveManifest do
  before :each do 
    @c = Factory(:company)
  end
  describe :make_manifest! do
    it "should create attachment and update time" do
      @man = @c.attachment_archive_manifests.create!(:start_at=>1.hour.ago)
      @base_time = 2.days.ago
      @tmp = mock("tmp")
      @tmp.should_receive(:unlink)
      @att = mock("attachment")
      @att.should_receive(:attached=).with(@tmp)
      @att.should_receive(:save!)
      @man.stub(:attachment).and_return(nil)
      @man.stub(:create_attachment).and_return(@att)
      @man.should_receive(:generate_manifest_tempfile!).with(@base_time).and_return(@tmp)
      @man.make_manifest! @base_time
      @man.reload
      @man.finish_at.should > 1.minute.ago
    end
  end

  describe :generate_manifest_tempfile! do
    before :each do
      @rel_date = 1.day.ago
      @ent = Factory(:entry,:importer=>@c,:broker_reference=>'123',:release_date=>@rel_date,:master_bills_of_lading=>'mbol',:arrival_date=>1.day.ago)
      @inv = Factory(:broker_invoice, :entry=>@ent, :invoice_date => 2.months.ago)
      @att1 = @ent.attachments.create!(:attached_file_name=>'a.txt',:attached_file_size=>100,:attachment_type=>'EDOC')
      @a_setup = @c.create_attachment_archive_setup(:start_date=>10.years.ago)
      # Make sure to create the archives and attachments separately to ensure the attachments are attached to the archvies
      # in a repeatable order
      @archive1 = @a_setup.create_entry_archive! "aname", 101
      @att2 = @ent.attachments.create!(:attached_file_name=>'b.txt',:attached_file_size=>100,:attachment_type=>'7501')
      @archive2 = @a_setup.create_entry_archive! "bname", 101
      @m = @c.attachment_archive_manifests.create!(:start_at=>Time.now)
    end
    after :each do 
      @tmp.unlink if @tmp
    end
    it "should create excel temp file" do
      @tmp = @m.generate_manifest_tempfile! 1.year.ago
      sheet = Spreadsheet.open(@tmp).worksheet(0)
      title_row = sheet.row(0)
      ["Archive Name","Archive Date","Broker Reference","Master Bill of Lading",
        "Release Date","Doc Type","Doc Name"].each_with_index do |n,i|
        title_row[i].should == n
      end
      
      # There's no real order involved in making the spreadsheet, so just make our own here so they appear in the order we expect
      lines = [sheet.row(1), sheet.row(2)].sort {|a, b| a[0] <=> b[0]}
      r = lines[0]

      r[0].should == "aname"
      r[1].should > 1.minute.ago
      r[2].should == '123'
      r[3].should == 'mbol'
      #not testing release date because I don't feel like fighting w/ date logic
      r[5].should == 'EDOC'
      r[6].should == @att1.unique_file_name 

      r = lines[1]
      r[0].should == "bname"
      r[1].should > 1.minute.ago
      r[2].should == '123'
      r[3].should == 'mbol'
      #not testing release date because I don't feel like fighting w/ date logic
      r[5].should == '7501'
      r[6].should == @att2.unique_file_name 

      r = sheet.row(3)
      r[0].should be_nil
    end
    it "should ignore old archives" do
      @archive1.update_attributes(:start_at=>5.years.ago)
      @tmp = @m.generate_manifest_tempfile! 1.year.ago
      sheet = Spreadsheet.open(@tmp).worksheet(0)
      sheet.row(1)[0].should == @archive2.name
      sheet.row(2)[0].should be_nil
    end
  end
end
