require 'spec_helper'
require 'zip/zip'

describe OpenChain::CustomHandler::AmscanZipLoader do
  before :each do 
    @h = OpenChain::CustomHandler::AmscanZipLoader
  end
  describe "process s3" do
    it "should download and call process_zip" do
      tf = mock("temp") 
      tf.should_receive("unlink")
      tf.should_receive("path").and_return("x")
      b = "bucket"
      k = "key"
      OpenChain::S3.should_receive(:download_to_tempfile).with(b,k).and_return(tf)
      @h.should_receive(:process_zip).with("x").and_return("y")
      @h.process_s3(b,k).should == "y"
    end
  end
  describe "process zip" do
    it "should process zip entry for each file in zip" do
      @h.should_receive(:process_zip_entry).with(instance_of(Zip::ZipEntry)).exactly(8).times
      @h.process_zip 'spec/support/bin/amscan_sample.zip'
    end
  end
  describe "process zip entry" do
    before :each do
      @ze = mock("ZipEntry")
    end
    it "should ignore non-jpg files" do
      LinkableAttachmentImportRule.should_not_receive(:import)
      @ze.should_receive(:name).and_return("/abc/def")
      @h.process_zip_entry(@ze).should be_nil
    end
    it "should process jpg file" do
      @ze.should_receive(:name).and_return("imp/123.jpg")
      @ze.should_receive(:extract).with("tmp/123.jpg")
      LinkableAttachmentImportRule.should_receive(:import).with('tmp/123.jpg',"123.jpg","/AMSCAN-ZIP","AMSCAN-123").and_return("abc")
      @h.process_zip_entry(@ze).should == "abc"
    end
    it "should process JPG file" do
      @ze.should_receive(:name).and_return("imp/123.JPG")
      @ze.should_receive(:extract).with("tmp/123.JPG")
      LinkableAttachmentImportRule.should_receive(:import).with('tmp/123.JPG',"123.JPG","/AMSCAN-ZIP","AMSCAN-123").and_return("abc")
      @h.process_zip_entry(@ze).should == "abc"
    end
    context "hard code values" do
      it "should include single numeric piece" do
        @ze.should_receive(:name).and_return("/x/y/123_ext.jpg")
        @ze.should_receive(:extract).with("tmp/123_ext.jpg")
        LinkableAttachmentImportRule.should_receive(:import).with('tmp/123_ext.jpg','123_ext.jpg','/AMSCAN-ZIP','AMSCAN-123').and_return('abc')
        @h.process_zip_entry(@ze).should == 'abc'
      end
      it "should separate consecutive numerics with period" do
        @ze.should_receive(:name).and_return("/x/y/123_04_ext.jpg")
        @ze.should_receive(:extract).with("tmp/123_04_ext.jpg")
        LinkableAttachmentImportRule.should_receive(:import).with('tmp/123_04_ext.jpg','123_04_ext.jpg','/AMSCAN-ZIP','AMSCAN-123.04').and_return('abc')
        @h.process_zip_entry(@ze).should == 'abc'
      end
    end
  end
end
