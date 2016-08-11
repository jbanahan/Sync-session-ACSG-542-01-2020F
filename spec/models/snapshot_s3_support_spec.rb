require 'spec_helper'

describe SnapshotS3Support do

  subject { Class.new { include SnapshotS3Support } }
  let! (:ms) { 
    ms = double("MasterSetup") 
    MasterSetup.stub(:get).and_return ms
    ms.stub(:system_code).and_return "syscode"
    ms
  }

  describe "bucket_name" do
    
    it "returns bucket name using rails env concatted with system code" do
      Rails.should_receive(:env).and_return "environment"
      expect(subject.bucket_name).to eq "environment.syscode.snapshots.vfitrack.net"
    end

    it "fails if bucket name is over 63 chars" do
      Rails.should_receive(:env).and_return "123456789012345678901234567890123"
      expect { subject.bucket_name }.to raise_error "Bucket name too long: 123456789012345678901234567890123.syscode.snapshots.vfitrack.net"
    end
  end

  describe "create_bucket_if_needed!" do
    it "creates bucket if it doesn't exist" do
      subject.should_receive(:bucket_name).and_return "bucket"
      OpenChain::S3.should_receive(:bucket_exists?).and_return false
      OpenChain::S3.should_receive(:create_bucket!).with("bucket", versioning: true)

      subject.create_bucket_if_needed!
    end

    it "does not create bucket if it exists" do
      subject.should_receive(:bucket_name).and_return "bucket"
      OpenChain::S3.should_receive(:bucket_exists?).and_return true
      OpenChain::S3.should_not_receive(:create_bucket!)

      subject.create_bucket_if_needed!
    end
  end

  describe "write_to_s3" do
    let (:entity) {
      e = Entry.new
      e.id = 100
      e
    }

    it "writes snapshot data to S3" do
      s3Obj = double("S3Object")
      bucketObj = double("S3Bucket")
      s3Obj.stub(:bucket).and_return bucketObj
      s3Obj.stub(:key).and_return "stubbed-key"
      bucketObj.stub(:name).and_return "stubbed-bucket"
      versionObj = double("S3Version")
      versionObj.stub(:version_id).and_return "stubbed-version"

      OpenChain::S3.should_receive(:upload_data).with("test.syscode.snapshots.vfitrack.net", "entry/100.json", "json").and_return [s3Obj, versionObj]

      values = subject.write_to_s3 "json", entity
      expect(values[:bucket]).to eq "stubbed-bucket"
      expect(values[:key]).to eq "stubbed-key"
      expect(values[:version]).to eq "stubbed-version"
    end
  end

  describe "s3_path" do
    let (:entity) {
      e = Entry.new
      e.id = 100
      e
    }

    it "returns path to use for storing snapshot data" do
      expect(subject.s3_path(entity)).to eq "entry/100.json"
    end

    it "raises an error if no id value has been set" do
      e = Entry.new
      expect {subject.s3_path(e)}.to raise_error "A snapshot path cannot be created for objects that do not have an id value. Entity Data = #{e.inspect}"
    end

    it "uses class' class name if it is not a core module" do
      a = AnswerComment.new
      a.id = 1

      expect(subject.s3_path(a)).to eq "answer_comment/1.json"
    end
  end
end