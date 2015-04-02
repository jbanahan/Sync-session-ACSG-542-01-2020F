require 'spec_helper'

describe OpenChain::CustomHandler::KewillDataRequester do

  describe "request_updated_since_last_run" do
    it "requests updated entry data via sql proxy client" do
      sql_proxy_client = double("SqlProxyClient")

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

      sql_proxy_client = double("SqlProxyClient")
      sql_proxy_client.should_receive(:request_updated_entry_numbers).with(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(original_request), instance_of(ActiveSupport::TimeWithZone))

      described_class.request_updated_since_last_run({'sql_proxy_client' => sql_proxy_client})

      # Check that a json key value was updated
      key = KeyJsonItem.updated_entry_data('last_request').first
      expect(key).not_to be_nil
      last_request = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(key.data['last_request'])
      expect(last_request).to be > ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(original_request)
    end

    it "does not update key store value if error occurs" do
      sql_proxy_client = double("SqlProxyClient")
      sql_proxy_client.should_receive(:request_updated_entry_numbers).and_raise "Error"
      expect {
        described_class.request_updated_since_last_run({'sql_proxy_client' => sql_proxy_client})
      }.to raise_error

      key = KeyJsonItem.updated_entry_data('last_request').first
      expect(key).not_to be_nil
      expect(key.data).to be_blank
    end
  end

  describe "request_since_hours_ago" do
    it "requests data using given hours ago value" do
      now = Time.zone.now
      Time.zone.should_receive(:now).and_return now
      sql_proxy_client = double("SqlProxyClient")
      sql_proxy_client.should_receive(:request_updated_entry_numbers).with(now - 1.hour, now)

      described_class.request_update_after_hours_ago 1, 'sql_proxy_client' => sql_proxy_client
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
      sql_proxy_client = double("SqlProxyClient")
      sql_proxy_client.should_receive(:request_entry_data).with("12345")

      described_class.request_entry_data '12345', Time.zone.now, sql_proxy_client
    end

    it "requests entry data if expected_update_time is in past" do
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", expected_update_time: 1.day.ago)
      sql_proxy_client = double("SqlProxyClient")
      sql_proxy_client.should_receive(:request_entry_data).with("12345")

      described_class.request_entry_data '12345', Time.zone.now, sql_proxy_client
    end

    it "requests entry data if alliance source system export date is in past" do
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", last_exported_from_source: 1.day.ago)
      sql_proxy_client = double("SqlProxyClient")
      sql_proxy_client.should_receive(:request_entry_data).with("12345")

      described_class.request_entry_data '12345', Time.zone.now, sql_proxy_client
    end

    it "does not request data if expected update time is newer than from request" do
      existing_expected = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", expected_update_time: existing_expected)

      sql_proxy_client = double("SqlProxyClient")
      sql_proxy_client.should_not_receive(:request_entry_data)

      described_class.request_entry_data '12345', (existing_expected - 1.second), sql_proxy_client
    end

    it "does not request data if last_exported_from_source is newer than from request" do
      existing_last_exported = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", last_exported_from_source: existing_last_exported)

      sql_proxy_client = double("SqlProxyClient")
      sql_proxy_client.should_not_receive(:request_entry_data)

      described_class.request_entry_data '12345', (existing_last_exported - 1.second), sql_proxy_client
    end
  end
end