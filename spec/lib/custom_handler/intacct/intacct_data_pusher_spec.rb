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


      @api_client.should_receive(:send_payable).with(p3, [])

      @p.push_payables
    end

    it "pushes payables to intacct that have checks associated with them" do
      p = IntacctPayable.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c2 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_payable_id: p.id

      @api_client.should_receive(:send_payable).with(p, [c1, c2])

      @p.push_payables

      p.reload
      expect(p.intacct_checks.size).to eq 2
      expect(p.intacct_checks).to include c1
      expect(p.intacct_checks).to include c2
    end

    it "does not include checks associated with another payable" do
      p = IntacctPayable.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_payable_id: -1

      @api_client.should_receive(:send_payable).with(p, [])

      @p.push_payables
    end

    it "does not include checks that already have an adjustment associated with them" do
      p = IntacctPayable.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_adjustment_key: "ADJ-123"

      @api_client.should_receive(:send_payable).with(p, [])

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

      @api_client.should_receive(:send_receivable).with(r3)

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

  describe "push_checks" do
    it "pushes checks to intacct" do
      c1 = IntacctCheck.create! vendor_number: "Vendor"
      c2 = IntacctCheck.create! vendor_number: "Vendor", intacct_errors: "Error"
      c2 = IntacctCheck.create! vendor_number: "Vendor", intacct_upload_date: Time.zone.now

      @api_client.should_receive(:send_check).with c1, false

      @p.push_checks
    end

    it "pushes checks issued after the payable to intacct" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI"
      p = IntacctPayable.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI", intacct_key: "KEY", intacct_upload_date: Time.zone.now, payable_type: IntacctPayable::PAYABLE_TYPE_BILL

      @api_client.should_receive(:send_check).with c1, true

      @p.push_checks
    end

    it "does not issue adjustments for a check if the payable has not yet been loaded" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI"
      p = IntacctPayable.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI"

      @api_client.should_receive(:send_check).with c1, false

      @p.push_checks
    end

    it "skips checks sent after being retrieved by initial lookup" do
      c = IntacctCheck.create! customer_number: "CUST"
      c.intacct_upload_date = Time.zone.now

      IntacctCheck.should_receive(:find).with(c.id).and_return c
      Lock.should_receive(:with_lock_retry).with(c).and_yield
      @api_client.should_not_receive(:send_check)

      @p.push_checks
    end
  end
end