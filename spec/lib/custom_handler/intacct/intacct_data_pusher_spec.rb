require 'spec_helper'
require 'open_chain/custom_handler/intacct/intacct_data_pusher'

describe OpenChain::CustomHandler::Intacct::IntacctDataPusher do

  before :each do
    @api_client = double("MockIntacctApiClient")
    @p = described_class.new @api_client
  end

  describe "push_payables" do
    it "pushes payables to intacct that have not already been sent or errored and are for the company specified" do
      p1 = IntacctPayable.create! intacct_upload_date: Time.zone.now, company: "C"
      p2 = IntacctPayable.create! intacct_errors: "Error!", company: "C"
      p3 = IntacctPayable.create! vendor_number: "Vendor", company: "C"
      p4 = IntacctPayable.create! vendor_number: "Vendor", company: "A"


      @api_client.should_receive(:send_payable).with(p3, [])

      @p.push_payables ["C"]
    end

    it "pushes payables to intacct that have checks associated with them" do
      p = IntacctPayable.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c2 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_payable_id: p.id

      @api_client.should_receive(:send_payable).with(p, [c1, c2])

      @p.push_payables ['C']

      p.reload
      expect(p.intacct_checks.size).to eq 2
      expect(p.intacct_checks).to include c1
      expect(p.intacct_checks).to include c2
    end

    it "does not include checks associated with another payable" do
      p = IntacctPayable.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_payable_id: -1

      @api_client.should_receive(:send_payable).with(p, [])

      @p.push_payables ['C']
    end

    it "does not include checks that already have an adjustment associated with them" do
      p = IntacctPayable.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_adjustment_key: "ADJ-123"

      @api_client.should_receive(:send_payable).with(p, [])

      @p.push_payables ['C']
    end

    it "skips payables that have been sent after being retrieved from initial lookup" do
      p3 = IntacctPayable.create! vendor_number: "Vendor", company: 'C'
      p3.intacct_upload_date = Time.zone.now
      # This is a bit of a hack so we can test the logic
      IntacctPayable.should_receive(:find).with(p3.id).and_return p3
      Lock.should_receive(:with_lock_retry).with(p3).and_yield
      @api_client.should_not_receive(:send_payable)

      @p.push_payables ['C']
    end
  end

  describe "push_receivables" do
    it "pushes receivables to intacct that have not already been sent or errored" do
      r1 = IntacctReceivable.create! intacct_upload_date: Time.zone.now, company: "C"
      r2 = IntacctReceivable.create! intacct_errors: "Error!", company: "C"
      r3 = IntacctReceivable.create! customer_number: "CUST", company: "C"
      r4 = IntacctReceivable.create! customer_number: "CUST", company: "A"

      @api_client.should_receive(:send_receivable).with(r3)

      @p.push_receivables ["C"]
    end

    it "skips receivables that have been sent after being retrieved from initial lookup" do
      r3 = IntacctReceivable.create! customer_number: "CUST", company: "C"
      r3.intacct_upload_date = Time.zone.now

      IntacctReceivable.should_receive(:find).with(r3.id).and_return r3
      Lock.should_receive(:with_lock_retry).with(r3).and_yield
      @api_client.should_not_receive(:send_receivable)

      @p.push_receivables ["C"]
    end
  end

  describe "push_checks" do
    it "pushes checks to intacct" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: "C"
      c2 = IntacctCheck.create! vendor_number: "Vendor", intacct_errors: "Error", company: "C"
      c3 = IntacctCheck.create! vendor_number: "Vendor", intacct_upload_date: Time.zone.now, company: "C"
      c4 = IntacctCheck.create! vendor_number: "Vendor", company: "A"

      @api_client.should_receive(:send_check).with c1, false

      @p.push_checks ["C"]
    end

    it "pushes checks issued after the payable to intacct" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI"
      p = IntacctPayable.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI", intacct_key: "KEY", intacct_upload_date: Time.zone.now, payable_type: IntacctPayable::PAYABLE_TYPE_BILL

      @api_client.should_receive(:send_check).with c1, true

      @p.push_checks ["VFI"]
    end

    it "does not issue adjustments for a check if the payable has not yet been loaded" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI"
      p = IntacctPayable.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI"

      @api_client.should_receive(:send_check).with c1, false

      @p.push_checks ["VFI"]
    end

    it "skips checks sent after being retrieved by initial lookup" do
      c = IntacctCheck.create! customer_number: "CUST", company: "VFI"
      c.intacct_upload_date = Time.zone.now

      IntacctCheck.should_receive(:find).with(c.id).and_return c
      Lock.should_receive(:with_lock_retry).with(c).and_yield
      @api_client.should_not_receive(:send_check)

      @p.push_checks ["VFI"]
    end

    it "does not push an adjustment if one has already been made" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI", intacct_adjustment_key: "ADJ-KEY"
      p = IntacctPayable.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI", intacct_key: "KEY", intacct_upload_date: Time.zone.now, payable_type: IntacctPayable::PAYABLE_TYPE_BILL

      @api_client.should_receive(:send_check).with c1, false

      @p.push_checks ["VFI"]
    end
  end

  describe "run_schedulable" do
    it "calls run with company list" do
      described_class.any_instance.should_receive(:run).with(['A', 'B'])
      described_class.run_schedulable JSON.parse('{"companies":["A", "B"]}')
    end

    it "raises an error if no companies are given" do
      expect{described_class.run_schedulable JSON.parse('{}')}.to raise_error
    end

    it "raises an error if non -array companies are given" do
      expect{described_class.run_schedulable JSON.parse('{"companies": "Test"}')}.to raise_error
    end

    it "raises an error if blank array is given" do
      expect{described_class.run_schedulable JSON.parse('{"companies": []}')}.to raise_error
    end
  end
end