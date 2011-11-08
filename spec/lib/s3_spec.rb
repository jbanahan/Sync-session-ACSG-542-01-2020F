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
      original_tempfile = Tempfile.new('abc')
      @content = "#{Time.now.to_f}"
      @key = "s3_io_#{Time.now.to_f}"
      original_tempfile.write @content
      original_tempfile.flush
      
      OpenChain::S3.upload_file @bucket, @key, original_tempfile
    end
    after(:each) do
      OpenChain::S3.delete @bucket, @key
    end
    it 'should get data' do
      OpenChain::S3.get_data(@bucket,@key).should == @content
    end
    it 'should round trip a file to tempfile' do
      new_tempfile = OpenChain::S3.download_to_tempfile @bucket, @key
      File.exist?(new_tempfile.path).should be_true
      IO.read(new_tempfile.path).should == @content
      new_tempfile.path.should =~ /\/tmp\/.*/
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

  end

end
