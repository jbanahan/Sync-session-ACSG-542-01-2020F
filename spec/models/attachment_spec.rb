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
    it "should use S3 to download to tempfile and yield the given block" do
      a = Attachment.new
      a.stub(:attached).and_return a
      a.should_receive(:path).and_return "path/to/file.txt"

      OpenChain::S3.should_receive(:download_to_tempfile).with('chain-io', "path/to/file.txt").and_yield "Test"

      a.download_to_tempfile do |f|
        f.should eq "Test"

        "Pass"
      end.should eq "Pass"
    end
  end
end
