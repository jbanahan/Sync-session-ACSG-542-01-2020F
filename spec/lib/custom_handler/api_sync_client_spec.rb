require 'spec_helper'

describe OpenChain::CustomHandler::ApiSyncClient do

  describe "sync" do

    before :each do
      @client = Class.new(OpenChain::CustomHandler::ApiSyncClient).new
      @client.stub(:syncable_type).and_return "TestObject"
      @client.stub(:sync_code).and_return "Test"
    end

    context "query method" do

      it "executes query, parses results, calls do_sync for each result, checks for more data to sync" do
        row_1 = [1, 'UID']
        row_2 = [2, 'UID2']
        query = "SELECT 1"

        @active_record_connection = double
        ActiveRecord::Base.stub(:connection).and_return @active_record_connection

        query_result = [OpenChain::CustomHandler::ApiSyncClient::ApiSyncObject.new(1, {'id' => 1}), OpenChain::CustomHandler::ApiSyncClient::ApiSyncObject.new(2, {'id' => 2})]
        @client.should_receive(:query).exactly(2).times.and_return query
        @active_record_connection.should_receive(:execute).with(query).and_return [row_1, row_2]
        @active_record_connection.should_receive(:execute).with(query).and_return []
        @client.should_receive(:process_query_result).with(row_1, last_result: false).and_return nil
        @client.should_receive(:process_query_result).with(row_2, last_result: true).and_return query_result
        @client.should_receive(:do_sync).with query_result[0]
        @client.should_receive(:do_sync).with query_result[1]

        @client.sync
      end

      it "does not repeatedly send the same failed object" do
        query = "SELECT 1, 'UID'"
        row_1 = [1, 'UID']
        query_result = OpenChain::CustomHandler::ApiSyncClient::ApiSyncObject.new(1, {'id' => 1})
        @client.should_receive(:query).and_return query
        @client.should_receive(:process_query_result).with(row_1, last_result: true).and_return query_result
        # Just blow up the first call we can easily do so inside the rescue'd block
        @client.should_receive(:retrieve_remote_data).and_raise "Error Message"
        @client.should_receive(:raise_sync_error?).and_return false

        @client.sync

        # We should have a sync record created w/ the error
        expect(SyncRecord.where(syncable_id: 1).first.try(:failure_message)).to eq "Error Message"
      end
    end

    context "object method" do
      it "iterates over objects to sync and calls do_sync for each result" do
        o1 = Object.new
        o2 = Object.new
        object_result = [OpenChain::CustomHandler::ApiSyncClient::ApiSyncObject.new(1, {'id' => 1}), OpenChain::CustomHandler::ApiSyncClient::ApiSyncObject.new(2, {'id' => 2})]

        result_set = double
        result_set.should_receive(:limit).with(500).and_return result_set
        result_set.should_receive(:each).and_yield(o1).and_yield(o2)
        @client.should_receive(:objects_to_sync).and_return result_set

        @client.should_receive(:process_object_result).with(o1).and_return nil
        @client.should_receive(:process_object_result).with(o2).and_return object_result
        @client.should_receive(:do_sync).with object_result[0]
        @client.should_receive(:do_sync).with object_result[1]

        @client.sync
      end

      it "continues to execute sync query until less than max results are found" do
        @client.stub(:max_object_results).and_return 1

        o1 = Object.new
        o2 = Object.new
        object_result = [OpenChain::CustomHandler::ApiSyncClient::ApiSyncObject.new(1, {'id' => 1}), OpenChain::CustomHandler::ApiSyncClient::ApiSyncObject.new(2, {'id' => 2})]

        result_set1 = double
        result_set1.stub(:limit).with(1).and_return result_set1
        result_set1.should_receive(:each).and_yield(o1)
        @client.should_receive(:objects_to_sync).and_return result_set1

        result_set2 = double
        result_set2.stub(:limit).with(1).and_return result_set2
        result_set2.should_receive(:each).and_yield(o2)
        @client.should_receive(:objects_to_sync).and_return result_set2

        result_set3 = double
        result_set3.stub(:limit).with(1).and_return result_set3
        result_set3.should_receive(:each)
        @client.should_receive(:objects_to_sync).and_return result_set3

        @client.should_receive(:process_object_result).with(o1).and_return object_result[0]
        @client.should_receive(:process_object_result).with(o2).and_return object_result[1]
        @client.should_receive(:do_sync).with object_result[0]
        @client.should_receive(:do_sync).with object_result[1]

        @client.sync
      end

      it "does not repeatedly send the same failed object" do
        o1 = Object.new
        object_result = OpenChain::CustomHandler::ApiSyncClient::ApiSyncObject.new(1, {'id' => 1})

        result_set = double
        result_set.should_receive(:limit).with(500).and_return result_set
        result_set.should_receive(:each).and_yield(o1)
        @client.should_receive(:objects_to_sync).and_return result_set

        @client.should_receive(:process_object_result).with(o1).and_return object_result

        # Just blow up the first call we can easily do so inside the rescue'd block
        @client.should_receive(:retrieve_remote_data).and_raise "Error Message"
        @client.should_receive(:raise_sync_error?).and_return false

        @client.sync

        # We should have a sync record created w/ the error
        expect(SyncRecord.where(syncable_id: 1).first.try(:failure_message)).to eq "Error Message"
      end
    end
  end

  describe "do_sync" do
    before :each do
      @client = Class.new(OpenChain::CustomHandler::ApiSyncClient) do
        attr_accessor :data_sent

        def test_sync obj
          do_sync obj
        end

        def retrieve_remote_data local_data
          {'id' => '1'}
        end

        def merge_remote_data_with_local remote_data, local_data
          remote_data.merge local_data
        end

        def send_remote_data remote_data
          @data_sent ||= []
          @data_sent << remote_data
          nil
        end

        def sync_code
          "test"
        end

        def syncable_type
          "Test"
        end
      end.new

      @sync_object = OpenChain::CustomHandler::ApiSyncClient::ApiSyncObject.new(1, {'uid' => 'uid'})
    end

    it "syncs local data with remote data" do
      @client.test_sync @sync_object

      #Verify the sync record was created
      sr = SyncRecord.where(syncable_id: 1, syncable_type: "Test", trading_partner: "test").first
      expect(sr).not_to be_nil

      # Verify the sync_record fingerprint uses the local data
      expect(sr.fingerprint).to eq Digest::MD5.hexdigest(@sync_object.local_data.to_json)
      expect(sr.sent_at.to_i).to be >= (Time.zone.now - 1.minute).to_i
      expect(sr.confirmed_at.to_i).to be > sr.sent_at.to_i
      expect(sr.confirmed_at.to_i).to be <= (Time.zone.now + 1.minute).to_i
    end

    it "does not sync or even request remote data if local data to send has same fingerprint as previous send" do
      sr = SyncRecord.create!(syncable_id: 1, syncable_type: "Test", trading_partner: "test", sent_at: (Time.zone.now() - 1.day), confirmed_at: (Time.zone.now() - 12.hours), fingerprint: Digest::MD5.hexdigest(@sync_object.local_data.to_json))
      @client.should_not_receive(:retrieve_remote_data)
      @client.test_sync @sync_object

      sr.reload
      expect(sr.sent_at.to_i).to be >= (Time.zone.now - 1.minute).to_i
      expect(sr.confirmed_at.to_i).to be > sr.sent_at.to_i
      expect(sr.confirmed_at.to_i).to be <= (Time.zone.now + 1.minute).to_i
    end

    it "ignores fingerpint if sync record indicates a problem" do
      SyncRecord.any_instance.should_receive(:problem?).and_return true
      sr = SyncRecord.create!(syncable_id: 1, syncable_type: "Test", trading_partner: "test", sent_at: (Time.zone.now() - 1.day), confirmed_at: (Time.zone.now() - 12.hours), fingerprint: Digest::MD5.hexdigest(@sync_object.local_data.to_json))
      @client.should_receive(:send_remote_data)
      @client.test_sync @sync_object

      sr.reload
      expect(sr.sent_at.to_i).to be >= (Time.zone.now - 1.minute).to_i
      expect(sr.confirmed_at.to_i).to be > sr.sent_at.to_i
      expect(sr.confirmed_at.to_i).to be <= (Time.zone.now + 1.minute).to_i
    end

    it "ignores fingerpint if sync record sent_at is null" do
      sr = SyncRecord.create!(syncable_id: 1, syncable_type: "Test", trading_partner: "test", fingerprint: Digest::MD5.hexdigest(@sync_object.local_data.to_json))
      @client.should_receive(:send_remote_data)
      @client.test_sync @sync_object

      sr.reload
      expect(sr.sent_at.to_i).to be >= (Time.zone.now - 1.minute).to_i
      expect(sr.confirmed_at.to_i).to be > sr.sent_at.to_i
      expect(sr.confirmed_at.to_i).to be <= (Time.zone.now + 1.minute).to_i
    end

    it "does not send_remote_data if the remote data retrieved has been unchanged" do
      @client.should_not_receive(:send_remote_data)

      # Make it so the same exact data passed in is returned by the merge data method,
      # thereby tripping the detector that will suppress the send_remote_data call
      @client.should_receive(:merge_remote_data_with_local) do |remote_data, local_data|
        remote_data
      end

      @client.test_sync @sync_object
      sr = SyncRecord.where(syncable_id: 1, syncable_type: "Test", trading_partner: "test").first
      expect(sr.sent_at.to_i).to be >= (Time.zone.now - 1.minute).to_i
      expect(sr.confirmed_at.to_i).to be > sr.sent_at.to_i
      expect(sr.confirmed_at.to_i).to be <= (Time.zone.now + 1.minute).to_i
      expect(sr.fingerprint).to eq Digest::MD5.hexdigest(@sync_object.local_data.to_json)
    end

    it "handles errors in do_sync and logs them as sync failure messages" do
      @client.should_receive(:retrieve_remote_data).and_raise "Error"

      expect {@client.test_sync @sync_object}.to raise_error

      sr = SyncRecord.where(syncable_id: 1, syncable_type: "Test", trading_partner: "test").first
      expect(sr.sent_at.to_i).to be >= (Time.zone.now - 1.minute).to_i
      expect(sr.confirmed_at).to be_nil
      expect(sr.failure_message).to eq "Error"
    end
  end
end