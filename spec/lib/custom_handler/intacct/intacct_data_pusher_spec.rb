require 'spec_helper'
require 'open_chain/custom_handler/intacct/intacct_data_pusher'

describe OpenChain::CustomHandler::Intacct::IntacctDataPusher do

  before :each do
    @api_client = double("MockIntacctApiClient")
    @p = described_class.new @api_client
  end

  describe "push_payables" do
    it "pushes payables to intacct that have not already been sent or errored" do
      p1 = IntacctPayable.create! intacct_upload_date: Time.zone.now
      p2 = IntacctPayable.create! intacct_errors: "Error!"
      p3 = IntacctPayable.create! vendor_number: "Vendor"


      @api_client.should_receive(:send_payable) do |payable|
        expect(payable.vendor_number).to eq p3.vendor_number
      end

      @p.push_payables
    end

    it "skips payables that have been sent after being retrieved from initial lookup" do
      p3 = IntacctPayable.create! vendor_number: "Vendor"
      p3.intacct_upload_date = Time.zone.now
      # This is a bit of a hack so we can test the logic
      IntacctPayable.should_receive(:find).with(p3.id).and_return p3
      Lock.should_receive(:with_lock_retry).with(p3).and_yield
      @api_client.should_not_receive(:send_payable)

      @p.push_payables
    end
  end

  describe "push_receivables" do
    it "pushes receivables to intacct that have not already been sent or errored" do
      r1 = IntacctReceivable.create! intacct_upload_date: Time.zone.now
      r2 = IntacctReceivable.create! intacct_errors: "Error!"
      r3 = IntacctReceivable.create! customer_number: "CUST"

      @api_client.should_receive(:send_receivable) do |recv|
        expect(recv.customer_number).to eq r3.customer_number
      end

      @p.push_receivables
    end

    it "skips receivables that have been sent after being retrieved from initial lookup" do
      r3 = IntacctReceivable.create! customer_number: "CUST"
      r3.intacct_upload_date = Time.zone.now

      IntacctReceivable.should_receive(:find).with(r3.id).and_return r3
      Lock.should_receive(:with_lock_retry).with(r3).and_yield
      @api_client.should_not_receive(:send_receivable)

      @p.push_receivables
    end
  end
end