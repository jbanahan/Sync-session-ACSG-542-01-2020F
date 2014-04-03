# encoding: utf-8
require 'spec_helper'

describe Attachment do
  describe "attachments_as_json" do
    it "should create json" do
      u = Factory(:user,first_name:'Jim',last_name:'Kirk')
      o = Factory(:order)
      a1 = o.attachments.create!(attached_file_name:'1.txt',attached_file_size:200,attachment_type:'mytype',uploaded_by_id:u.id)
      a2 = o.attachments.create!(attached_file_name:'2.txt',attached_file_size:1000000,attachment_type:'2type',uploaded_by_id:u.id)
      h = Attachment.attachments_as_json o
      h[:attachable][:id].should == o.id
      h[:attachable][:type].should == "Order"
      ha = h[:attachments]
      ha.size.should == 2
      ha1 = ha.first
      {a1=>ha[0],a2=>ha[1]}.each do |k,v|
        v[:name].should == k.attached_file_name
        v[:size].should == ActionController::Base.helpers.number_to_human_size(k.attached_file_size)
        v[:type].should == k.attachment_type
        v[:user][:id].should == u.id
        v[:user][:full_name].should == u.full_name
        v[:id].should == k.id
      end
    end
  end
  describe "unique_file_name" do
    it "should generate unique name" do
      a = Attachment.create(:attached_file_name=>"a.txt")
      a.unique_file_name.should == "#{a.id}-a.txt"

      a.update_attributes(:attachment_type=>"type")
      a.unique_file_name.should == "type-#{a.id}-a.txt"      
    end
    it 'should sanitize the filename' do
      a = Attachment.create(:attached_file_name=>"a.txt", :attachment_type => "Doc / Type")
      a.unique_file_name.should == "Doc _ Type-#{a.id}-a.txt"
    end
  end

  describe "add_original_filename_method" do
    it "should add original_filename accessor methods to subject object" do
      a = "test"
      Attachment.add_original_filename_method a

      a.original_filename.should be_nil
      a.original_filename = "file.txt"
      a.original_filename.should == "file.txt"
    end
  end

  describe "get_santized_filename" do
    it "should change non-latin1 chars to _" do
      f = Attachment.get_sanitized_filename "照片 014.jpg"
      f.should == "__ 014.jpg"
    end

    it "should convert invalid windows filename characters to _" do
      f = Attachment.get_sanitized_filename "\/:*?\"<>|.jpg"
      f.should == "________.jpg"
    end

    it "should convert non-printing ascii characters to _" do
      f = Attachment.get_sanitized_filename "\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      f.should == "_________________________.jpg"
    end
  end

  describe "sanitize callback" do
    it "should sanitize the attached filename" do
      a = Attachment.new
      a.attached_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      a.save
      a.attached_file_name.should == "___________________________________.jpg"
    end
  end

  describe "sanitize_filename" do
    it "should sanitize filename and update the filename attribute" do
      a = Attachment.new
      a.attached_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      Attachment.sanitize_filename a, :attached
      a.attached_file_name.should == "___________________________________.jpg"
    end

    it "should work for non-Attachment based models" do
      r = ReportResult.new
      r.report_data_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      Attachment.sanitize_filename r, :report_data
      r.report_data_file_name.should == "___________________________________.jpg"
    end
  end

  describe "email_attachments" do

    before :each do
      @x = Tempfile.new("temp-a.txt")
      @y = Tempfile.new("temp-b.txt")
      @z = Tempfile.new("temp-c.txt")
    end

    after :each do
      [@x, @y, @z].each {|tfile| tfile.close! unless tfile.closed?}
    end

    it "should return true after success" do
      param_hash = {to_address: "me@there.com", email_subject: "Test subject", email_body: "Test body", ids_to_include: [1, 2, 3]}
      a = Attachment.new(attached_file_name: "a.txt")
      b = Attachment.new(attached_file_name: "b.txt")
      c = Attachment.new(attached_file_name: "c.txt")
      a.id = 1; b.id = 2; c.id = 3
      a.save!; b.save!; c.save!
      Attachment.should_receive(:find).with(1).and_return a
      Attachment.should_receive(:find).with(2).and_return b
      Attachment.should_receive(:find).with(3).and_return c
      a.should_receive(:download_to_tempfile).and_return @x
      b.should_receive(:download_to_tempfile).and_return @y
      c.should_receive(:download_to_tempfile).and_return @z
      Attachment.email_attachments(param_hash).should be_true
    end

    it "should send an email with the correct attachments" do
      param_hash = {to_address: "me@there.com", email_subject: "Test subject", email_body: "Test body", ids_to_include: [1, 2, 3]}
      a = Attachment.new(attached_file_name: "a.txt")
      b = Attachment.new(attached_file_name: "b.txt")
      c = Attachment.new(attached_file_name: "c.txt")
      a.id = 1; b.id = 2; c.id = 3
      a.save!; b.save!; c.save!
      Attachment.should_receive(:find).with(1).and_return a
      Attachment.should_receive(:find).with(2).and_return b
      Attachment.should_receive(:find).with(3).and_return c
      a.should_receive(:download_to_tempfile).and_return @x
      b.should_receive(:download_to_tempfile).and_return @y
      c.should_receive(:download_to_tempfile).and_return @z

      Attachment.email_attachments(param_hash)

      m = OpenMailer.deliveries.last
      m.attachments.length.should == 3
      m.attachments[0].filename.should == "a.txt"
      m.attachments[1].filename.should == "b.txt"
      m.attachments[2].filename.should == "c.txt"
    end

    it "should send an email to the correct recipient" do
      param_hash = {to_address: "me@there.com", email_subject: "Test subject", email_body: "Test body", ids_to_include: [1, 2, 3]}
      a = Attachment.new(attached_file_name: "a.txt")
      b = Attachment.new(attached_file_name: "b.txt")
      c = Attachment.new(attached_file_name: "c.txt")
      a.id = 1; b.id = 2; c.id = 3
      a.save!; b.save!; c.save!
      Attachment.should_receive(:find).with(1).and_return a
      Attachment.should_receive(:find).with(2).and_return b
      Attachment.should_receive(:find).with(3).and_return c
      a.should_receive(:download_to_tempfile).and_return @x
      b.should_receive(:download_to_tempfile).and_return @y
      c.should_receive(:download_to_tempfile).and_return @z

      Attachment.email_attachments(param_hash)

      m = OpenMailer.deliveries.last
      m.to.first.should == "me@there.com"
    end
  end

  describe "push_to_google_drive" do
    it "should download and attachment and push it to google drive" do
      a = Attachment.new
      a.attached_file_name = "file.txt"
      a.save

      # mock the attached call, which fails unless we actually upload a file
      attached = double("attached")
      options = {:bucket => "bucket"}
      Attachment.any_instance.stub(:attached).and_return attached
      attached.should_receive(:options).and_return options
      attached.should_receive(:path).and_return "s3_path"

      temp = double("Tempfile")
      account = "me@there.com"
      path = "folder/subfolder"
      options = {}

      OpenChain::S3.should_receive(:download_to_tempfile).with("bucket", "s3_path").and_yield temp
      OpenChain::GoogleDrive.should_receive(:upload_file).with(account, "#{path}/file.txt", temp, options)

      Attachment.push_to_google_drive path, a.id, account, options
    end
  end

  describe "download_to_tempfile" do
    it "should use S3 to download to tempfile and yield the given block (if block given)" do
      a = Attachment.new
      a.stub(:attached).and_return a
      a.should_receive(:path).and_return "path/to/file.txt"

      OpenChain::S3.should_receive(:download_to_tempfile).with('chain-io', "path/to/file.txt").and_yield "Test"

      a.download_to_tempfile do |f|
        f.should eq "Test"

        "Pass"
      end.should eq "Pass"
    end

    it "should use S3 to download to tempfile and return the tempfile (if no block given)" do
      a = Attachment.new
      a.stub(:attached).and_return a
      a.should_receive(:path).and_return "path/to/file.txt"
      OpenChain::S3.should_receive(:download_to_tempfile).with('chain-io', "path/to/file.txt").and_return "Test"
      tfile = a.download_to_tempfile
      tfile.should eq "Test"
    end
  end

  describe "stitchable_attachment?" do
    it 'identifies major image formats as stitchable' do
      ['.tif', '.tiff', '.jpg', '.jpeg', '.gif', '.png', '.bmp', '.pdf'].each do |ext|
        a = Attachment.new attached_file_name: "file#{ext}"
        expect(a.stitchable_attachment?).to be_true
      end
    end

    it 'identifies non-images as not stitchable' do
      a = Attachment.new attached_file_name: "file.blahblah"
      expect(a.stitchable_attachment?).to be_false
    end
  end
end
