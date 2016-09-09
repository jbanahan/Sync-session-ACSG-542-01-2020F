require 'spec_helper'
require 'open_chain/s3'

describe OpenChain::S3, s3: true do

  let! (:bucket) { OpenChain::S3.bucket_name 'test' }
  let (:tempfile_content) { "#{Time.now.to_f}" }
  let (:test_tempfile) { Tempfile.new('abc') }
  let (:key) { "s3_io_#{Time.now.to_f}.txt" }

  def upload_tempfile options = {}
    test_tempfile.write tempfile_content
    test_tempfile.flush

    file = OpenChain::S3.upload_file bucket, key, test_tempfile, options
    @uploaded = true
    file
  end

  before :each do
    @uploaded = false
  end

  after(:each) do
    if @uploaded
      OpenChain::S3.delete bucket, key
    end

    test_tempfile.close! unless test_tempfile.closed?
  end

  describe 'bucket name' do
    it 'should return test bucket based on environment' do
      expect(OpenChain::S3.bucket_name).to eq('chain-io-test')
    end
    it 'should return production bucket' do
      expect(OpenChain::S3.bucket_name('production')).to eq('chain-io')
    end
    it 'should return development bucket' do
      expect(OpenChain::S3.bucket_name('development')).to eq('chain-io-dev')
    end
    it 'should return test bucket' do
      expect(OpenChain::S3.bucket_name('test')).to eq('chain-io-test')
    end
  end

  describe "bucket_exists?" do
    let (:bucket_name) { "abc" }
    let (:bucket_double) {
      s3_double = double('s3')
      allow(described_class).to receive(:aws_s3).and_return(s3_double)
      bucket_double = double('bucket')
      allow(s3_double).to receive(:buckets).and_return( bucket_name => bucket_double )
      bucket_double
    }

    it "should find existing bucket" do
      expect(bucket_double).to receive(:exists?).and_return true
      expect(described_class.bucket_exists?(bucket_name)).to be_truthy
    end
    it "should return false if no bucket" do
      expect(bucket_double).to receive(:exists?).and_return false
      expect(described_class.bucket_exists?(bucket_name)).to be_falsey
    end
  end

  describe "create_bucket" do
    let (:s3_double) {
      s3_double = double('s3')
      allow(described_class).to receive(:aws_s3).and_return(s3_double)
      s3_double
    }

    it "should create bucket" do
      new_bucket_double = double('newbucket')
      buckets_double = double('buckets')
      expect(buckets_double).to receive(:create).with("ABC").and_return(new_bucket_double)
      expect(s3_double).to receive(:buckets).and_return(buckets_double)
      expect(described_class.create_bucket! "ABC").to eq new_bucket_double
    end
    it "should enable versioning based on option" do
      new_bucket_double = double('newbucket')
      expect(new_bucket_double).to receive(:enable_versioning)
      buckets_double = double('buckets')
      expect(buckets_double).to receive(:create).with("ABC").and_return(new_bucket_double)
      expect(s3_double).to receive(:buckets).and_return(buckets_double)
      expect(described_class.create_bucket! "ABC", versioning: true).to eq new_bucket_double
    end
  end

  describe "get_data" do
    context "with actual s3 data" do
      before(:each) do
        upload_tempfile
      end

      it 'retrieves data from s3' do
        expect(OpenChain::S3.get_data(bucket, key)).to eq(tempfile_content)
      end

      it 'should stream data file to IO object' do
        io = StringIO.new
        expect(OpenChain::S3.get_data(bucket, key, io)).to be_nil
        expect(io.read).to eq(tempfile_content)
      end
    end

    it "should retry failed downloads 3 times" do
      file = double("S3Object")
      expect(OpenChain::S3).to receive(:s3_versioned_object).exactly(3).times.and_return file
      expect(file).to receive(:read).exactly(3).times.and_raise "Failure"

      expect {OpenChain::S3.get_data(bucket, key)}.to raise_error "Failure"
    end

    it "should retry failed downloads 3 times and truncate in between times" do
      io = StringIO.new
      expect(io).to receive(:truncate).with(0).exactly(2).times
      expect(OpenChain::S3).to receive(:s3_versioned_object).exactly(3).times.and_raise "Failure"
      expect {OpenChain::S3.get_data(bucket, key, io)}.to raise_error "Failure"
    end

    it 'should retry failed downloads 3 times and rewind in between' do
      io = double("IO")
      expect(io).to receive(:rewind).exactly(2).times
      expect(OpenChain::S3).to receive(:s3_versioned_object).exactly(3).times.and_raise "Failure"
      expect {OpenChain::S3.get_data(bucket, key, io)}.to raise_error "Failure"
    end
  end

  describe "download_to_tempfile" do
    context "with actual s3 data" do
      before :each do
        upload_tempfile
      end

      it 'round trips a file to tempfile' do
        new_tempfile = OpenChain::S3.download_to_tempfile bucket, key
        begin
          expect(File.exist?(new_tempfile.path)).to be_truthy
          expect(IO.read(new_tempfile.path)).to eq(tempfile_content)
          expect(new_tempfile).to be_a Tempfile
          expect(File.basename(new_tempfile.path)).to match(/^s3_io.+\.txt$/)
        ensure
          new_tempfile.close! if new_tempfile && !new_tempfile.closed?
        end
      end

      it 'should yield the downloaded tempfile to a block' do
        tempfile = nil
        OpenChain::S3.download_to_tempfile bucket, key do |t|
          tempfile = t
          expect(File.basename(t.path)).to match(/^s3_io.+\.txt$/)
          expect(IO.read(t)).to eq(tempfile_content)
        end

        # Path is nil if the file has been unlinked
        expect(tempfile.path).to be_nil
      end

      it 'should ensure the tempfile is unlinked if block raises an error' do
        tempfile = nil
        expect {
          OpenChain::S3.download_to_tempfile bucket, key do |t|
            tempfile = t
            raise Exception, "Error"
          end
        }.to raise_error Exception

        # Path is nil if the file has been unlinked
        expect(tempfile.path).to be_nil
      end

      it 'should not fail if file key is missing a file extension' do
        new_key = "test"
        AWS::S3.new(AWS_CREDENTIALS).buckets[bucket].objects[key].rename_to new_key
        new_tempfile = OpenChain::S3.download_to_tempfile bucket, new_key
        begin
          expect(File.exist?(new_tempfile.path)).to be_truthy
          expect(IO.read(new_tempfile.path)).to eq(tempfile_content)
          expect(new_tempfile).to be_a Tempfile
          expect(File.basename(new_tempfile.path)).to match(/^test.+/)
          expect(File.extname(new_tempfile.path)).to eq("")
        ensure
          begin
            OpenChain::S3.delete bucket, new_key
          ensure
            new_tempfile.close! if new_tempfile && !new_tempfile.closed?  
          end
        end
      end

      it "adds original_filename method to tempfile" do
        original_filename = nil
        OpenChain::S3.download_to_tempfile(bucket, key, original_filename: "file.txt") do |t|
          original_filename = t.original_filename
        end

        expect(original_filename).to eq "file.txt"
      end
    end
    
    it 'should ensure the tempfile is unlinked if an error occurs while downloading' do
      # Need to do this with mocks, since there's no external references made to the tempfile
      # created while the download is ocurring
      tempfile = double('tempfile')
      expect(OpenChain::S3).to receive(:create_tempfile).and_return tempfile
      expect(tempfile).to receive(:binmode)
      expect(tempfile).to receive(:close!)
      expect(OpenChain::S3).to receive(:get_versioned_data).and_raise "Error!"
      expect {OpenChain::S3.download_to_tempfile bucket, key}.to raise_error "Error!"
    end
  end

  describe "exists?" do
    context 'with live data' do
      before :each do
        upload_tempfile
      end
      it 'should return true when key exists' do
        expect(OpenChain::S3.exists?(bucket, key)).to be_truthy
      end
      it 'should return false when key does not exist' do
        expect(OpenChain::S3.exists?( bucket,"#{key}not")).to be_falsey
      end
    end
  end

  describe "delete" do
    context 'with live data' do
      before :each do
        upload_tempfile
      end

      it 'deletes file' do
        expect(OpenChain::S3.exists?(bucket, key)).to be_truthy
        expect(OpenChain::S3.delete(bucket, key)).to be_nil
        expect(OpenChain::S3.exists?(bucket, key)).to be_falsey
      end
    end
    
  end

  describe 'integration keys' do
    context "with single subfolder" do
      let(:keys) { ["2011-12/26/subfolder/2/a.txt","2011-12/26/subfolder/2/b.txt"] }

      before :each do
        keys.each {|my_key| OpenChain::S3.upload_file bucket, my_key, test_tempfile}
      end
      after :each do
        keys.each {|my_key| OpenChain::S3.delete bucket, my_key}
      end
      it 'should get keys from integration bucket by date ordered by last modified date' do
        # Last modified has a 1 second precision, so sleep at least 2 seconds to make sure
        # this doesn't randomly fail.  Not ideal, but I don't know how to actually force an
        # out of band last modified date update on an s3_object.

        # Bizarrely, if I put the sleep AFTER doing the integration keys call the upload_file call below
        # (specifically the s3_object.write method) blocks for like 20 seconds.  Possible aws-sdk bug or ruby 2
        # bug with leaking socket handle or something?  This wasn't happening w/ 1.9.3.
        retry_expect {
          expect(OpenChain::S3).to receive(:integration_bucket_name).at_least(2).times.and_return(bucket)
          found_keys = []
          OpenChain::S3.integration_keys(Date.new(2011,12,26), "subfolder/2") {|key| found_keys << key }
          expect(found_keys).to eq keys
        }

        retry_expect {
          Tempfile.open('test') do |f|
            f.binmode
            f << "Test"
            f.flush

            # Lets update key[0] and it should then be returned second
            # Need to use a different file with different content, otherwise S3 object is too smart
            # and doesn't actually send the data if it didn't change
            OpenChain::S3.upload_file bucket, keys[0], f
            found_keys = []
            OpenChain::S3.integration_keys(Date.new(2011,12,26), "subfolder/2") {|key| found_keys << key }
            expect(found_keys).to eq [keys[1], keys[0]]
          end
        }
      end

      it 'strips leading slashes from subfolder name' do
        expect(OpenChain::S3).to receive(:integration_bucket_name).and_return(bucket)
        found_keys = []
        OpenChain::S3.integration_keys(Date.new(2011,12,26), "/subfolder/2") {|key| found_keys << key }
        expect(found_keys).to eq keys
      end
    end

    context "with different subfolders" do
      let(:keys) { ["2011-12/26/subfolder/1/a.txt","2011-12/26/subfolder/2/b.txt"] }

      before :each do
        keys.each {|my_key| OpenChain::S3.upload_file bucket, my_key, test_tempfile}
      end
      after :each do
        keys.each {|my_key| OpenChain::S3.delete bucket, my_key}
      end

      it 'checks each subfolder given and yields integration keys' do
        retry_expect {
          allow(OpenChain::S3).to receive(:integration_bucket_name).and_return(bucket)
          found_keys = []
          OpenChain::S3.integration_keys(Date.new(2011,12,26), ["/subfolder/2", "/subfolder/1"]) {|key| found_keys << key }
          expect(found_keys).to eq [keys[1], keys[0]]
        }
      end
    end
  end

  describe "url_for" do
    it "should return a url for the specified bucket / key" do
      url = OpenChain::S3.url_for "bucket", "path/to/file.txt"
      expect(url).to match /^https:\/\/bucket.+\/path\/to\/file\.txt.+Expires/

      # Expires should be default be 1 minute
      expires_at = url.match(/Expires=(.*)&/)[1].to_i
      expect(expires_at - Time.now.to_i).to be <= 60
    end

    it "should return a url for the specified bucket / key, allow expires_in to be set, and accept options", s3: true do
      url = OpenChain::S3.url_for "bucket", "path/to/file.txt", 10.minutes, {:response_content_type => "application/pdf"}
      expect(url).to match /^https:\/\/bucket.+\/path\/to\/file\.txt.+Expires/

      expires_at = url.match(/Expires=(.*)&/)[1].to_i
      time = (expires_at - Time.now.to_i)
      expect(time).to be <= 600
      expect(time).to be >= 595

      expect(url).to match "response-content-type=application%2Fpdf"
    end
  end

  describe "parse_full_s3_path" do
    it "splits a path string into bucket and key values", s3: true do
      expect(OpenChain::S3.parse_full_s3_path "/bucket/path/to/file.pdf").to eq ["bucket", "path/to/file.pdf"]
    end

    it "handles missing leading slashes", s3: true do
      expect(OpenChain::S3.parse_full_s3_path "bucket/path/to/file.pdf").to eq ["bucket", "path/to/file.pdf"]
    end
  end

  describe "with_s3_tempfile" do
    let (:s3_obj) {
      s3_obj = double("S3Object")
      s3_bucket = double("S3Object")
      allow(s3_obj).to receive(:bucket).and_return s3_bucket
      allow(s3_obj).to receive(:key).and_return "uuid/temp/file.txt"
      allow(s3_obj).to receive(:exists?).and_return true
      allow(s3_bucket).to receive(:name).and_return "chainio-temp"

      s3_obj
    }
    # Excessive stubbing below due to preventing s3 uploads...upload tests themselves are in specs for upload_file, to
    # which this method defers for uploading (likewise for delete)
    before :each do
      ms = double "MasterSetup"
      allow(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:uuid).and_return "uuid"
    end

    it "yields an s3_file uploaded to s3" do
      fake_file = double("File")
      allow(fake_file).to receive(:path).and_return "/path/to/file.txt"

      expect(OpenChain::S3).to receive(:upload_file).with("chainio-temp", "uuid/temp/file.txt", fake_file).and_return [s3_obj, nil]
      expect(OpenChain::S3).to receive(:delete).with("chainio-temp", "uuid/temp/file.txt")

      my_obj = nil
      OpenChain::S3.with_s3_tempfile(fake_file) {|obj| my_obj = obj}
      expect(my_obj).to eq s3_obj
    end

    it "cleans up even if yielded block raises an error" do
      fake_file = double("File")
      allow(fake_file).to receive(:path).and_return "/path/to/file.txt"

      expect(OpenChain::S3).to receive(:upload_file).and_return [s3_obj, nil]
      expect(OpenChain::S3).to receive(:delete).with(s3_obj.bucket.name, s3_obj.key)

      expect {OpenChain::S3.with_s3_tempfile(fake_file) {|obj| raise "Error"} }.to raise_error "Error"
    end

    it "uses original_filename if local file responds to that" do
      fake_file = double("File")
      allow(fake_file).to receive(:path).and_return "/path/to/file.txt"
      allow(fake_file).to receive(:original_filename).and_return "original.txt"

      expect(OpenChain::S3).to receive(:upload_file).with("chainio-temp", "uuid/temp/original.txt", fake_file).and_return [s3_obj, nil]
      expect(OpenChain::S3).to receive(:delete)

      my_obj = nil
      OpenChain::S3.with_s3_tempfile(fake_file) {|obj| my_obj = obj}
    end
  end

  describe "create_s3_tempfile" do
    before :each do
      ms = double "MasterSetup"
      allow(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:uuid).and_return "uuid"
    end

    it "creates a tempfile on s3" do
      fake_file = double("File")
      allow(fake_file).to receive(:path).and_return "/path/to/file.txt"
      obj = Object.new
      expect(OpenChain::S3).to receive(:upload_file).with("chainio-temp", "uuid/temp/file.txt", fake_file).and_return [obj, nil]

      # Just ensure the create method returns whatever the upload file method returns (in prod, this'll be an S3Object)
      expect(OpenChain::S3.create_s3_tempfile fake_file).to eq obj
    end

    it "uses original_filename if local file responds to that" do
      fake_file = double("File")
      allow(fake_file).to receive(:path).and_return "/path/to/file.txt"
      allow(fake_file).to receive(:original_filename).and_return "original.txt"

      expect(OpenChain::S3).to receive(:upload_file).with("chainio-temp", "uuid/temp/original.txt", fake_file)
      OpenChain::S3.create_s3_tempfile fake_file
    end
  end

  describe "metadata" do
    before :each do
      upload_tempfile metadata: {"Meta" => "Value"}
    end

    it "retrieves metadata value from s3 object" do
      # Note the change of case on the meta-data key
      expect(OpenChain::S3.metadata "meta", bucket, key).to eq "Value"
    end
  end
end
