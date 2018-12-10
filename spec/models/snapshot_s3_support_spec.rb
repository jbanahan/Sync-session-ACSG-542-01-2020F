require 'spec_helper'

describe SnapshotS3Support do

  subject { Class.new { include SnapshotS3Support } }
  let! (:ms) { 
    ms = double("MasterSetup") 
    allow(MasterSetup).to receive(:get).and_return ms
    allow(ms).to receive(:system_code).and_return "syscode"
    ms
  }

  describe "bucket_name" do
    
    it "returns bucket name using rails env concatted with system code" do
      expect(Rails).to receive(:env).and_return "environment"
      expect(subject.bucket_name).to eq "environment.syscode.snapshots.vfitrack.net"
    end

    it "fails if bucket name is over 63 chars" do
      expect(Rails).to receive(:env).and_return "123456789012345678901234567890123"
      expect { subject.bucket_name }.to raise_error "Bucket name too long: 123456789012345678901234567890123.syscode.snapshots.vfitrack.net"
    end
  end

  describe "create_bucket_if_needed!" do
    it "creates bucket if it doesn't exist" do
      expect(subject).to receive(:bucket_name).and_return "bucket"
      expect(OpenChain::S3).to receive(:bucket_exists?).and_return false
      expect(OpenChain::S3).to receive(:create_bucket!).with("bucket", versioning: true)

      subject.create_bucket_if_needed!
    end

    it "does not create bucket if it exists" do
      expect(subject).to receive(:bucket_name).and_return "bucket"
      expect(OpenChain::S3).to receive(:bucket_exists?).and_return true
      expect(OpenChain::S3).not_to receive(:create_bucket!)

      subject.create_bucket_if_needed!
    end
  end

  describe "write_to_s3" do
    let (:entity) {
      e = Entry.new
      e.id = 100
      e
    }

    let (:s3_obj) {
      s3_obj = double("OpenChain::S3::UploadResult")
      allow(s3_obj).to receive(:key).and_return "stubbed-key"
      allow(s3_obj).to receive(:bucket).and_return "stubbed-bucket"
      allow(s3_obj).to receive(:version).and_return "stubbed-version"
      s3_obj
    }

    it "writes snapshot data to S3" do
      # Using block form because sometimes the gzip binary data can differ between the expectation and the actual implemetation (time-based?)
      # So just roundtrip the compression to make sure the passed data is valid
      expect(OpenChain::S3).to receive(:upload_data) do |bucket, key, content, opts|
        expect(bucket).to eq "test.syscode.snapshots.vfitrack.net"
        expect(key).to eq "entry/100.json"
        expect(ActiveSupport::Gzip.decompress(content)).to eq "json"
        expect(opts).to eq({content_encoding:"gzip", content_type: "application/json"})
        s3_obj 
      end

      values = subject.write_to_s3 "json", entity
      expect(values[:bucket]).to eq "stubbed-bucket"
      expect(values[:key]).to eq "stubbed-key"
      expect(values[:version]).to eq "stubbed-version"
    end

    it "allows passing in path prefix" do
      # Using block form because sometimes the gzip binary data can differ between the expectation and the actual implemetation (time-based?)
      # So just roundtrip the compression to make sure the passed data is valid
      expect(OpenChain::S3).to receive(:upload_data) do |bucket, key, content, opts|
        expect(bucket).to eq "test.syscode.snapshots.vfitrack.net"
        expect(key).to eq "prefix/entry/100.json"
        expect(ActiveSupport::Gzip.decompress(content)).to eq "json"
        expect(opts).to eq({content_encoding:"gzip", content_type: "application/json"})
        s3_obj 
      end
      values = subject.write_to_s3 "json", entity, path_prefix: 'prefix'
    end

    it "raises an error if upload does not return a version" do
      s3_obj = double("OpenChain::S3::UploadResult")
      allow(s3_obj).to receive(:key).and_return "stubbed-key"
      allow(s3_obj).to receive(:bucket).and_return "stubbed-bucket"
      allow(s3_obj).to receive(:version).and_return nil

      expect(OpenChain::S3).to receive(:upload_data).and_return s3_obj

      expect { subject.write_to_s3 "json", entity }.to raise_error "Cannot upload snapshots to unversioned bucket.  You must enable versioning on bucket 'stubbed-bucket'."
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

    it "allows passing a path prefix" do
      expect(subject.s3_path(entity, path_prefix: "path/prefix")).to eq "path/prefix/entry/100.json"
    end
  end

  describe "copy_to_deleted_bucket" do
    let (:testing_system_code) { "testing-system-code" }
    let! (:master_setup) { 
      ms = stub_master_setup 
      allow(ms).to receive(:system_code).and_return testing_system_code
      ms
    }
    let (:source_bucket) { "test-bucket" }
    let (:source_path) { "path/to/doc.txt" }
    let (:env) { "test-environment"}

    subject { Class.new { include SnapshotS3Support }.new }

    before :each do 
      allow(subject).to receive(:bucket).and_return source_bucket
      allow(MasterSetup).to receive(:rails_env).and_return env
    end
    
    it "calls OpenChain::S3.copy_object with correct information" do
      allow(subject).to receive(:doc_path).and_return source_path
      allow(subject).to receive(:version).and_return "version"

      expect(OpenChain::S3).to receive(:copy_object).with(source_bucket, source_path, "test-environment.deleted-snapshots.vfitrack.net", "#{testing_system_code}/#{source_path}", from_version: "version")
      expect(subject.copy_to_deleted_bucket).to eq true
    end

    it "no-ops if doc_path is blank" do
      allow(subject).to receive(:doc_path).and_return nil
      expect(OpenChain::S3).not_to receive(:copy_object)
      expect(subject.copy_to_deleted_bucket).to eq false
    end

  end
end