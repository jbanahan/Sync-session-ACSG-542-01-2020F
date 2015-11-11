require 'spec_helper'

describe OpenChain::CustomHandler::KewillDataRequester do

  describe "request_updated_since_last_run" do
    it "requests updated entry data via sql proxy client" do
      sql_proxy_client = double("KewillSqlProxyClient")

      start_date = nil
      end_date = nil
      sql_proxy_client.should_receive(:request_updated_entry_numbers) do |start_d, end_d|
        start_date = start_d
        end_date = end_d
        true
      end

      described_class.request_updated_since_last_run({'sql_proxy_client' => sql_proxy_client})

      # Check that a json key value was created
      key = KeyJsonItem.updated_entry_data('last_request').first
      expect(key).not_to be_nil
      expect(key.data['last_request']).to eq end_date.strftime "%Y-%m-%d %H:%M"
    end

    it "uses existing key value to determine when last request was done" do
      original_request = "2015-03-01 00:00"
      KeyJsonItem.updated_entry_data('last_request').create! json_data: "{\"last_request\":\"#{original_request}\"}"

      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_updated_entry_numbers).with(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(original_request), instance_of(ActiveSupport::TimeWithZone), nil)
      described_class.request_updated_since_last_run({'sql_proxy_client' => sql_proxy_client})

      # Check that a json key value was updated
      key = KeyJsonItem.updated_entry_data('last_request').first
      expect(key).not_to be_nil
      last_request = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(key.data['last_request'])
      expect(last_request).to be > ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(original_request)
    end

    it "does not update key store value if error occurs" do
      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_updated_entry_numbers).and_raise "Error"
      expect {
        described_class.request_updated_since_last_run({'sql_proxy_client' => sql_proxy_client})
      }.to raise_error

      key = KeyJsonItem.updated_entry_data('last_request').first
      expect(key).not_to be_nil
      expect(key.data).to be_blank
    end

    it "passes through customer_numbers opt if non-blank" do
      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_updated_entry_numbers).with(instance_of(ActiveSupport::TimeWithZone), instance_of(ActiveSupport::TimeWithZone), "TESTING")
      described_class.request_updated_since_last_run({'sql_proxy_client' => sql_proxy_client, "customer_numbers" => "TESTING"})
    end

    it "offsets request time by X seconds if requested" do
      original_request = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse "2015-03-01 00:00"
      now = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now

      KeyJsonItem.updated_entry_data('last_request').create! json_data: "{\"last_request\":\"#{original_request.strftime("%Y-%m-%d %H:%M")}\"}"
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"].stub(:now).and_return now

      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_updated_entry_numbers).with(original_request - 2.minutes, now - 2.minutes, nil)
      described_class.request_updated_since_last_run({'sql_proxy_client' => sql_proxy_client, 'offset' => '120'})

      # Check that a json key value was updated to the actual runtime (not the offset time)
      key = KeyJsonItem.updated_entry_data('last_request').first
      expect(key).not_to be_nil
      expect(key.data['last_request']).to eq now.strftime("%Y-%m-%d %H:%M")
    end
  end

  describe "request_since_hours_ago" do
    it "requests data using given hours ago value" do
      now = Time.zone.now
      Time.zone.should_receive(:now).and_return now
      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_updated_entry_numbers).with(now - 1.hour, now, nil)

      described_class.request_update_after_hours_ago 1, 'sql_proxy_client' => sql_proxy_client
    end

    it "requests data using given hours ago value, passing customer_number" do
      now = Time.zone.now
      Time.zone.should_receive(:now).and_return now
      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_updated_entry_numbers).with(now - 1.hour, now, "TEST, TESTING")
      described_class.request_update_after_hours_ago 1, 'sql_proxy_client' => sql_proxy_client, 'customer_numbers' => "TEST, TESTING"
    end
  end

  describe "run_schedulable" do
    it "defaults to updated since last run call" do
      described_class.should_receive(:request_updated_since_last_run)

      described_class.run_schedulable
    end

    it "uses request update after hours ago if hours ago value is present" do
      described_class.should_receive(:request_update_after_hours_ago).with(10, {'hours_ago' => 10})
      described_class.run_schedulable({'hours_ago' => 10})
    end
  end

  describe "request_entry_data" do
    it "requests entry data if entry doesn't exist yet" do
      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_entry_data).with("12345")

      described_class.request_entry_data '12345', Time.zone.now, nil, sql_proxy_client
    end

    it "requests entry data if expected_update_time is in past" do
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", expected_update_time: 1.day.ago)
      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_entry_data).with("12345")

      described_class.request_entry_data '12345', Time.zone.now, nil, sql_proxy_client
    end

    it "requests entry data if alliance source system export date is in past" do
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", last_exported_from_source: 1.day.ago)
      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_entry_data).with("12345")

      described_class.request_entry_data '12345', Time.zone.now, nil, sql_proxy_client
    end

    it "does not request data if expected update time is newer than from request" do
      existing_expected = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", expected_update_time: existing_expected)

      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_not_receive(:request_entry_data)

      described_class.request_entry_data '12345', (existing_expected - 1.second), nil, sql_proxy_client
    end

    it "does not request data if last_exported_from_source is newer than from request" do
      existing_last_exported = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", last_exported_from_source: existing_last_exported)

      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_not_receive(:request_entry_data)

      described_class.request_entry_data '12345', (existing_last_exported - 1.second), nil, sql_proxy_client
    end

    it "does not request data if invoice count is same as the remote" do
      existing_expected = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", expected_update_time: existing_expected)
      Factory(:broker_invoice, entry: entry)

      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_not_receive(:request_entry_data)

      described_class.request_entry_data '12345', (existing_expected - 1.second), 1, sql_proxy_client
    end

    it "requests data if invoice count is less than the remote count" do
      existing_expected = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", expected_update_time: existing_expected)

      sql_proxy_client = double("KewillSqlProxyClient")
      sql_proxy_client.should_receive(:request_entry_data).with("12345")

      described_class.request_entry_data '12345', (existing_expected - 1.second), 1, sql_proxy_client
    end
  end

  describe "request_entry_batch_data" do
    it "requests entry data using old style data" do
      described_class.stub(:delay).and_return described_class
      described_class.should_receive(:request_entry_data).with("1", "123", nil)

      described_class.request_entry_batch_data({"1"=>"123"}.to_json)
    end

    it "requests entry data using new data format" do
      described_class.stub(:delay).and_return described_class
      described_class.should_receive(:request_entry_data).with("1", "123", 2)

      described_class.request_entry_batch_data({"1"=> {'date' => '123', 'inv' => 2}}.to_json)
    end

    it "requests entry data using new data format with no invoices" do
      described_class.stub(:delay).and_return described_class
      described_class.should_receive(:request_entry_data).with("1", "123", nil)

      described_class.request_entry_batch_data({"1"=> {'date' => '123'}}.to_json)
    end

    it "requests entry data for each value in the given hash" do
      described_class.stub(:delay).and_return described_class
      described_class.should_receive(:request_entry_data).with("1", "123", nil)
      described_class.should_receive(:request_entry_data).with("2", "234", 1)

      described_class.request_entry_batch_data({"1"=>"123", "2"=>{"date" => "234", "inv"=>1}})
    end
    

    it "does not not request data if a job is already queued for this data" do
      dj = Delayed::Job.new
      dj.handler = "--- !ruby/object:Delayed::PerformableMethod
object: !ruby/class 'OpenChain::CustomHandler::KewillDataRequester'
method_name: :request_entry_data
args:
- '1'
- 201506041052
"
      dj.save!
      described_class.should_not_receive(:delay)
      described_class.should_not_receive(:request_entry_data)
      described_class.request_entry_batch_data({"1"=>"123"})
    end
  end
end