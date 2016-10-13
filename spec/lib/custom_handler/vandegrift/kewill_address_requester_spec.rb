require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::KewillAddressRequester do

  describe "run_schedulable" do
    subject { described_class }
    it "uses sql proxy client to request address updates" do
      expect(subject).to receive(:poll).and_yield ActiveSupport::TimeZone["America/New_York"].parse("2016-10-10 12:00"), Time.zone.now

      sql_proxy = instance_double(OpenChain::KewillSqlProxyClient)
      expect(subject).to receive(:sql_proxy_client).and_return sql_proxy
      expect(sql_proxy).to receive(:request_address_updates).with Date.new(2016, 10, 10)

      subject.run_schedulable
    end
  end
end