# encoding: utf-8
require 'spec_helper'

describe Attachment do
  describe "unique_file_name" do
    it "should generate unique name" do
      a = Attachment.create(:attached_file_name=>"a.txt")
      a.unique_file_name.should == "#{a.id}-a.txt"

      a.update_attributes(:attachment_type=>"type")
      a.unique_file_name.should == "type-#{a.id}-a.txt"      
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

  describe "sanitize_filename" do
    it "should change non-latin1 chars to _" do
      a = Attachment.new
      a.attached_file_name = "照片 014.jpg"
      Attachment.sanitize_filename a, :attached
      a.attached_file_name.should == "__ 014.jpg"
    end

    it "should convert invalid windows filename characters to _" do
      a = Attachment.new
      a.attached_file_name = "\/:*?\"<>|.jpg"
      Attachment.sanitize_filename a, :attached
      a.attached_file_name.should == "________.jpg"
    end

    it "should convert non-printing ascii characters to _" do
      a = Attachment.new
      a.attached_file_name = "\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      Attachment.sanitize_filename a, :attached
      a.attached_file_name.should == "_________________________.jpg"
    end

    it "should work for non-Attachment based models" do
      r = ReportResult.new
      r.report_data_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      Attachment.sanitize_filename r, :report_data
      r.report_data_file_name.should == "___________________________________.jpg"
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

  describe "push_to_google_drive" do
    it "should download and attachment and push it to google drive" do
      a = Attachment.new
      a.attached_file_name = "file.txt"
      a.save

      # mock the attached call, which fails unless we actually upload a file
      attached = double("attached")
      Attachment.any_instance.stub(:attached).and_return attached
      attached.should_receive(:options).and_return attached
      attached.should_receive(:fog_directory).and_return  "s3_bucket"
      attached.should_receive(:path).and_return "s3_path"

      temp = double("Tempfile")
      account = "me@there.com"
      path = "folder/subfolder"
      options = {}

      OpenChain::S3.should_receive(:download_to_tempfile).with("s3_bucket", "s3_path").and_yield temp
      OpenChain::GoogleDrive.should_receive(:upload_file).with(account, "#{path}/file.txt", temp, options)

      Attachment.push_to_google_drive path, a.id, account, options
    end
  end
end
