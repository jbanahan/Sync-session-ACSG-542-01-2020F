require 'spec_helper'
require 'open_chain/s3'

describe OpenChain::S3 do
  before(:all) do
    @bucket = OpenChain::S3.bucket_name 'test'
  end
  describe 'bucket name' do
    it 'should return test bucket based on environment' do
      OpenChain::S3.bucket_name.should == 'chain-io-test'
    end
    it 'should return production bucket' do
      OpenChain::S3.bucket_name('production').should == 'chain-io'
    end
    it 'should return development bucket' do
      OpenChain::S3.bucket_name('development').should == 'chain-io-dev'
    end
    it 'should return test bucket' do
      OpenChain::S3.bucket_name('test').should == 'chain-io-test'
    end
  end
  describe 'IO' do
    before(:each) do
      @original_tempfile = Tempfile.new('abc')
      @content = "#{Time.now.to_f}"
      @key = "s3_io_#{Time.now.to_f}.txt"
      @original_tempfile.write @content
      @original_tempfile.flush
      
      OpenChain::S3.upload_file @bucket, @key, @original_tempfile
    end
    after(:each) do
      OpenChain::S3.delete @bucket, @key
      @original_tempfile.close!
    end
    it 'should get data' do
      OpenChain::S3.get_data(@bucket,@key).should == @content
    end

    it "should retry failed downloads 3 times" do
      file = double("S3Object")
      OpenChain::S3.should_receive(:s3_file).exactly(3).times.and_return file
      file.should_receive(:read).exactly(3).times.and_raise "Failure"

      expect {OpenChain::S3.get_data(@bucket,@key)}.to raise_error "Failure"
    end

    it "should retry failed downloads 3 times and truncate in between times" do
      io = StringIO.new
      io.should_receive(:truncate).with(0).exactly(2).times
      OpenChain::S3.should_receive(:s3_file).exactly(3).times.and_raise "Failure"
      expect {OpenChain::S3.get_data(@bucket, @key, io)}.to raise_error "Failure"
    end

    it 'should retry failed downloads 3 times and rewind in between' do
      io = double("IO")
      io.should_receive(:rewind).exactly(2).times
      OpenChain::S3.should_receive(:s3_file).exactly(3).times.and_raise "Failure"
      expect {OpenChain::S3.get_data(@bucket, @key, io)}.to raise_error "Failure"
    end

    it 'should round trip a file to tempfile' do
      new_tempfile = OpenChain::S3.download_to_tempfile @bucket, @key
      begin
        File.exist?(new_tempfile.path).should be_true
        IO.read(new_tempfile.path).should == @content
        new_tempfile.path.should =~ /\/tmp\/.*/
        File.basename(new_tempfile.path).should =~ /^s3_io.+\.txt$/
      ensure
        new_tempfile.close!
      end
    end

    it 'should stream data file to IO object' do
      io = StringIO.new
      OpenChain::S3.get_data(@bucket, @key, io).should be_nil
      io.read.should == @content
    end

    it 'should ensure the tempfile is unlinked if an error occurs while downloading' do
      # Need to do this with mocks, since there's no external references made to the tempfile
      # created while the download is ocurring
      tempfile = double('tempfile')
      OpenChain::S3.should_receive(:create_tempfile).and_return tempfile
      tempfile.should_receive(:binmode)
      tempfile.should_receive(:close!)
      OpenChain::S3.should_receive(:get_data).and_raise "Error!"
      expect {OpenChain::S3.download_to_tempfile @bucket, @key}.to raise_error "Error!"
    end

    it 'should yield the downloaded tempfile to a block' do
      tempfile = nil
      OpenChain::S3.download_to_tempfile @bucket, @key do |t|
        tempfile = t
        File.basename(t.path).should =~ /^s3_io.+\.txt$/
        IO.read(t).should == @content
      end

      # Path is nil if the file has been unlinked
      tempfile.path.should be_nil
    end

    it 'should ensure the tempfile is unlinked if block raises an error' do
      tempfile = nil
      expect {
        OpenChain::S3.download_to_tempfile @bucket, @key do |t|
          tempfile = t
          raise Exception, "Error"
        end
      }.to raise_error Exception

      # Path is nil if the file has been unlinked
      tempfile.path.should be_nil
    end

    it 'should not fail if file key is missing a file extension' do
      new_key = "test"
      AWS::S3.new(AWS_CREDENTIALS).buckets[@bucket].objects[@key].rename_to new_key
      new_tempfile = OpenChain::S3.download_to_tempfile @bucket, new_key
      begin
        File.exist?(new_tempfile.path).should be_true
        IO.read(new_tempfile.path).should == @content
        new_tempfile.path.should =~ /\/tmp\/.*/
        File.basename(new_tempfile.path).should =~ /^test.+/
        File.extname(new_tempfile.path).should == ""
      ensure
        new_tempfile.close!
      end
    end
    
    describe 'exists?' do
      it 'should return true when key exists' do
        OpenChain::S3.exists?(@bucket,@key).should be_true
      end
      it 'should return false when key does not exist' do
        OpenChain::S3.exists?(@bucket,"#{@key}not").should be_false
      end
    end

    describe 'delete' do
      it 'should return true when there is something there and it is deleted' do
        OpenChain::S3.exists?(@bucket,@key).should be_true
        OpenChain::S3.delete(@bucket,@key)
        OpenChain::S3.exists?(@bucket,@key).should be_false
      end
    end
    describe 'integration keys' do
      context "with single subfolder" do
        before :each do
          @my_keys = ["2011-12/26/subfolder/2/a.txt","2011-12/26/subfolder/2/b.txt"] #find these
          @my_keys.each {|my_key| OpenChain::S3.upload_file @bucket, my_key, @original_tempfile}
        end
        after :each do
          @my_keys.each {|my_key| OpenChain::S3.delete @bucket, my_key}
        end
        it 'should get keys from integration bucket by date ordered by last modified date' do
          # Last modified has a 1 second precision, so sleep at least 2 seconds to make sure
          # this doesn't randomly fail.  Not ideal, but I don't know how to actually force an 
          # out of band last modified date update on an s3_object.

          # Bizarrely, if I put the sleep AFTER doing the integration keys call the upload_file call below
          # (specifically the s3_object.write method) blocks for like 20 seconds.  Possible aws-sdk bug or ruby 2
          # bug with leaking socket handle or something?  This wasn't happening w/ 1.9.3.
          sleep 2
          OpenChain::S3.should_receive(:integration_bucket_name).at_least(2).times.and_return(@bucket)
          found_keys = []
          OpenChain::S3.integration_keys(Date.new(2011,12,26), "subfolder/2") {|key| found_keys << key }
          found_keys[0].should == @my_keys[0]
          found_keys[1].should == @my_keys[1]

          Tempfile.open('test') do |f|
            f.binmode
            f << "Test"
            f.flush

            # Lets update key[0] and it should then be returned second
            # Need to use a different file with different content, otherwise S3 object is too smart
            # and doesn't actually send the data if it didn't change
            OpenChain::S3.upload_file @bucket, @my_keys[0], f
            found_keys = []
            OpenChain::S3.integration_keys(Date.new(2011,12,26), "subfolder/2") {|key| found_keys << key }
            found_keys[0].should == @my_keys[1]
            found_keys[1].should == @my_keys[0]
          end
        end

        it 'strips leading slashes from subfolder name' do
          OpenChain::S3.should_receive(:integration_bucket_name).and_return(@bucket)
          found_keys = []
          OpenChain::S3.integration_keys(Date.new(2011,12,26), "/subfolder/2") {|key| found_keys << key }
          found_keys[0].should == @my_keys[0]
          found_keys[1].should == @my_keys[1]
        end
      end

      context "with multiple subfolders" do
        before :each do
          @my_keys = ["2011-12/26/subfolder/1/a.txt","2011-12/26/subfolder/2/b.txt"]
          @my_keys.each {|my_key| OpenChain::S3.upload_file @bucket, my_key, @original_tempfile}
        end

        after :each do
          @my_keys.each {|my_key| OpenChain::S3.delete @bucket, my_key}
        end

        it 'checks each subfolder given and yields integration keys' do
          OpenChain::S3.should_receive(:integration_bucket_name).exactly(2).times.and_return(@bucket)
          found_keys = []
          OpenChain::S3.integration_keys(Date.new(2011,12,26), ["/subfolder/2", "/subfolder/1"]) {|key| found_keys << key }
          found_keys[0].should == @my_keys[1]
          found_keys[1].should == @my_keys[0]
        end
      end
    end
  end

  describe :url_for do
    it "should return a url for the specified bucket / key" do
      url = OpenChain::S3.url_for "bucket", "path/to/file.txt"
      url.should match /^https:\/\/bucket.+\/path\/to\/file\.txt.+Expires/

      # Expires should be default be 1 minute
      expires_at = url.match(/Expires=(.*)&/)[1].to_i
      (expires_at - Time.now.to_i).should <= 60
    end

    it "should return a url for the specified bucket / key, allow expires_in to be set, and accept options" do
      url = OpenChain::S3.url_for "bucket", "path/to/file.txt", 10.minutes, {:response_content_type => "application/pdf"}
      url.should match /^https:\/\/bucket.+\/path\/to\/file\.txt.+Expires/

      expires_at = url.match(/Expires=(.*)&/)[1].to_i
      time = (expires_at - Time.now.to_i)
      time.should <= 600
      time.should >= 595

      url.should match "response-content-type=application%2Fpdf"
    end
  end

  describe "parse_full_s3_path" do
    it "splits a path string into bucket and key values" do
      expect(OpenChain::S3.parse_full_s3_path "/bucket/path/to/file.pdf").to eq ["bucket", "path/to/file.pdf"]
    end

    it "handles missing leading slashes" do
      expect(OpenChain::S3.parse_full_s3_path "bucket/path/to/file.pdf").to eq ["bucket", "path/to/file.pdf"]
    end
  end

  describe "download_to_tempfile" do
    before :each do
      @tempfile = Tempfile.new ['temp', '.txt']
      @tempfile << "Contents"
      @tempfile.flush
      @tempfile.rewind
    end

    after :each do
      @tempfile.close! unless @tempfile.closed?
    end

    it "downloads S3 path to tempfile" do
      OpenChain::S3.should_receive(:create_tempfile).and_return @tempfile
      OpenChain::S3.should_receive(:get_data).with('bucket', 'path', @tempfile).and_return @tempfile
      file = OpenChain::S3.download_to_tempfile 'bucket', 'path'
      expect(file).to eq @tempfile
      expect(file.respond_to? :original_filename).to be_false
    end

    it "downloads s3 path to tempfile and adds original_filename method" do
      OpenChain::S3.should_receive(:create_tempfile).and_return @tempfile
      OpenChain::S3.should_receive(:get_data).with('bucket', 'path', @tempfile).and_return @tempfile
      file = OpenChain::S3.download_to_tempfile 'bucket', 'path', original_filename: 'file.txt'
      expect(file).to eq @tempfile
      expect(file.original_filename).to eq "file.txt"
    end

    it "yields downloaded file" do
      OpenChain::S3.should_receive(:create_tempfile).and_return @tempfile
      OpenChain::S3.should_receive(:get_data).with('bucket', 'path', @tempfile).and_return @tempfile
      OpenChain::S3.download_to_tempfile('bucket', 'path', original_filename: 'file.txt') do |f|
        expect(f).to eq @tempfile
        expect(f.original_filename).to eq "file.txt"
      end
      expect(@tempfile.closed?).to be_true
    end

    it "ensures exceptions in block still closes file" do
      OpenChain::S3.should_receive(:create_tempfile).and_return @tempfile
      OpenChain::S3.should_receive(:get_data).with('bucket', 'path', @tempfile).and_return @tempfile
      expect {
        OpenChain::S3.download_to_tempfile('bucket', 'path', original_filename: 'file.txt') do |f|
          raise "Error"
        end  
      }.to raise_error
      
      expect(@tempfile.closed?).to be_true
    end
  end
end
