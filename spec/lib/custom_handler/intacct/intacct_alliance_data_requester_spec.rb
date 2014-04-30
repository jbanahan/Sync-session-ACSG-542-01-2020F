require 'spec_helper'
require 'open_chain/custom_handler/intacct/intacct_alliance_data_requester'

describe OpenChain::CustomHandler::Intacct::IntacctAllianceDataRequester do

  describe "run_schedulable" do
    it "runs without args" do
      described_class.any_instance.should_receive(:request_invoice_numbers).with(no_args())
      described_class.run_schedulable
    end

    it "runs with days_ago option" do
      described_class.any_instance.should_receive(:request_invoice_numbers).with 5
      described_class.run_schedulable({'days_ago' => "5"})
    end
  end

  describe "request_invoice_numbers" do
    before :each do
      @proxy = double("OpenChain::SqlProxyClient")
      @r = described_class.new @proxy
    end

    it "requests invoice numbers defaulting to 5 days ago" do
      @proxy.should_receive(:request_alliance_invoice_numbers_since).with (Time.zone.now - 5.days).to_date
      @r.request_invoice_numbers
    end

    it "requests invoice numbers using specified days ago" do
      @proxy.should_receive(:request_alliance_invoice_numbers_since).with (Time.zone.now - 10.days).to_date
      @r.request_invoice_numbers 10
    end
  end

end
