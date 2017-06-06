require 'spec_helper'

describe OpenChain::BulkAction::BulkActionRunner do
  before :each do
    @bucket_name = 'bn'
    allow(OpenChain::S3).to receive(:bucket_name).and_return @bucket_name
    @ac = double('action_class')
    allow(@ac).to receive(:bulk_type).and_return 'My Name'
    @opts = {'a'=>'b'}
    @u = double(:user)
    allow(@u).to receive(:id).and_return 99
  end
  describe '#process_from_parameters' do
    it 'should process search run if sr_id exists' do
      params = {'sr_id'=>'3'}
      sr = double('search_run')
      expect(SearchRun).to receive(:find).with('3').and_return sr
      expect(described_class).to receive(:process_search_run).with @u, sr, @ac, @opts

      described_class.process_from_parameters @u, params, @ac, @opts
    end
    it 'should process primary keys if they exist' do
      params = {'pk'=>{'0'=>'1','1'=>'2','2'=>'3'}}
      expect(described_class).to receive(:process_object_ids).with @u, ['1','2','3'], @ac, @opts
      described_class.process_from_parameters @u, params, @ac, @opts
    end

    it 'should raise error for bad params' do
      params = {'other'=>'stuff'}
      expect {described_class.process_from_parameters @u, params, @ac, @opts}.to raise_error "Invalid parameters, missing sr_id or pk array: #{params.to_s}"
    end
  end
  describe '#process_search_run' do
    it 'should get ids from search run and process_object_ids' do

      sr = double(:search_run)
      expect(sr).to receive(:find_all_object_keys).and_return([1,2,3].to_enum)
      expect(described_class).to receive(:process_object_ids).with(@u,[1,2,3],@ac,@opts)

      described_class.process_search_run(@u,sr,@ac,@opts)
    end

    it 'should throw exception if more values found than allowed' do
      @opts[:max_results] = 2

      sr = double(:search_run)
      expect(sr).to receive(:find_all_object_keys).and_return([1,2,3].to_enum)
      expect {described_class.process_search_run(@u,sr,@ac,@opts)}.to raise_error OpenChain::BulkAction::TooManyBulkObjectsError
    end

    it 'should not throw exception if results do not exceed maximum' do
      @opts[:max_results] = 3

      sr = double(:search_run)
      expect(sr).to receive(:find_all_object_keys).and_return([1,2,3].to_enum)
      expect(described_class).to receive(:process_object_ids).with(@u,[1,2,3],@ac,@opts)

      described_class.process_search_run(@u,sr,@ac,@opts)
    end
  end
  describe '#process_object_ids' do
    it 'should write to s3 and delay run_s3' do
      Timecop.freeze(Time.now) do
        data_to_write = {user_id:@u.id,keys:[1,2,3],opts:@opts}.to_json
        key = "#{MasterSetup.get.uuid}/bulk_action_run/#{Digest::MD5.hexdigest data_to_write}-#{Time.now.to_i}.json"
        expect(OpenChain::S3).to receive(:upload_data).with(@bucket_name,key,data_to_write)
        expect(described_class).to receive(:delay).and_return(described_class)
        expect(described_class).to receive(:run_s3).with(key,@ac)

        described_class.process_object_ids @u, [1,2,3], @ac, @opts
      end
    end
  end
  describe '#run_s3' do
    it "should retrieve S3 file, run IDs, delete S3 file" do
      bpl = BulkProcessLog.create!(user:Factory(:user),bulk_type:'whatever')
      expect(User).to receive(:find).with(99).and_return @u
      expect(BulkProcessLog).to receive(:with_log).with(@u,@ac.bulk_type).and_yield bpl
      base_hash = {user_id:99,keys:[1,2,3],opts:{'abc'=>'def'}}
      data = base_hash.to_json
      key = 'abc'
      expect(@ac).to receive(:act).with(@u, 1, base_hash[:opts], bpl, 1)
      expect(@ac).to receive(:act).with(@u, 2, base_hash[:opts], bpl, 2)
      expect(@ac).to receive(:act).with(@u, 3, base_hash[:opts], bpl, 3)

      expect(OpenChain::S3).to receive(:get_data).with(@bucket_name,key).and_return data
      expect(OpenChain::S3).to receive(:delete).with(@bucket_name,key)
      described_class.run_s3 key, @ac
    end
  end
end
