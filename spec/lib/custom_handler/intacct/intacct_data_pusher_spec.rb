require 'open_chain/custom_handler/intacct/intacct_data_pusher'

describe OpenChain::CustomHandler::Intacct::IntacctDataPusher do

  subject { described_class.new api_client }

  let (:api_client) { instance_double(OpenChain::CustomHandler::Intacct::IntacctClient) }

  describe "push_payables" do
    it "pushes payables to intacct that have not already been sent or errored and are for the company specified" do
      p1 = IntacctPayable.create! intacct_upload_date: Time.zone.now, company: "C"
      p2 = IntacctPayable.create! intacct_errors: "Error!", company: "C"
      p3 = IntacctPayable.create! vendor_number: "Vendor", company: "C"
      p4 = IntacctPayable.create! vendor_number: "Vendor", company: "A"


      expect(api_client).to receive(:send_payable).with(p3, [])

      subject.push_payables ["C"]
    end

    it "pushes payables to intacct that have checks associated with them" do
      p = IntacctPayable.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c2 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_payable_id: p.id

      expect(api_client).to receive(:send_payable).with(p, [c1, c2])

      subject.push_payables ['C']

      p.reload
      expect(p.intacct_checks.size).to eq 2
      expect(p.intacct_checks).to include c1
      expect(p.intacct_checks).to include c2
    end

    it "does not include checks associated with another payable" do
      p = IntacctPayable.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_payable_id: -1

      expect(api_client).to receive(:send_payable).with(p, [])

      subject.push_payables ['C']
    end

    it "does not include checks that already have an adjustment associated with them" do
      p = IntacctPayable.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_adjustment_key: "ADJ-123"

      expect(api_client).to receive(:send_payable).with(p, [])

      subject.push_payables ['C']
    end

    it "skips payables that have been sent after being retrieved from initial lookup" do
      p3 = IntacctPayable.create! vendor_number: "Vendor", company: 'C'
      p3.intacct_upload_date = Time.zone.now
      # This is a bit of a hack so we can test the logic
      expect(IntacctPayable).to receive(:find).with(p3.id).and_return p3
      expect(Lock).to receive(:db_lock).with(p3).and_yield
      expect(api_client).not_to receive(:send_payable)

      subject.push_payables ['C']
    end
  end

  describe "push_receivables" do
    it "pushes receivables to intacct that have not already been sent or errored" do
      r1 = IntacctReceivable.create! intacct_upload_date: Time.zone.now, company: "C"
      r2 = IntacctReceivable.create! intacct_errors: "Error!", company: "C"
      r3 = IntacctReceivable.create! customer_number: "CUST", company: "C"
      r4 = IntacctReceivable.create! customer_number: "CUST", company: "A"

      expect(api_client).to receive(:send_receivable).with(r3)

      subject.push_receivables ["C"]
    end

    it "skips receivables that have been sent after being retrieved from initial lookup" do
      r3 = IntacctReceivable.create! customer_number: "CUST", company: "C"
      r3.intacct_upload_date = Time.zone.now

      expect(IntacctReceivable).to receive(:find).with(r3.id).and_return r3
      expect(Lock).to receive(:db_lock).with(r3).and_yield
      expect(api_client).not_to receive(:send_receivable)

      subject.push_receivables ["C"]
    end
  end

  describe "push_checks" do
    it "pushes checks to intacct" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: "C"
      c2 = IntacctCheck.create! vendor_number: "Vendor", intacct_errors: "Error", company: "C"
      c3 = IntacctCheck.create! vendor_number: "Vendor", intacct_upload_date: Time.zone.now, company: "C"
      c4 = IntacctCheck.create! vendor_number: "Vendor", company: "A"

      expect(api_client).to receive(:send_check).with c1, false

      subject.push_checks ["C"]
    end

    it "pushes checks issued after the payable to intacct" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI"
      p = IntacctPayable.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI", intacct_key: "KEY", intacct_upload_date: Time.zone.now, payable_type: IntacctPayable::PAYABLE_TYPE_BILL

      expect(api_client).to receive(:send_check).with c1, true

      subject.push_checks ["VFI"]
    end

    it "does not issue adjustments for a check if the payable has not yet been loaded" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI"
      p = IntacctPayable.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI"

      expect(api_client).to receive(:send_check).with c1, false

      subject.push_checks ["VFI"]
    end

    it "skips checks sent after being retrieved by initial lookup" do
      c = IntacctCheck.create! customer_number: "CUST", company: "VFI"
      c.intacct_upload_date = Time.zone.now

      expect(IntacctCheck).to receive(:find).with(c.id).and_return c
      expect(Lock).to receive(:db_lock).with(c).and_yield
      expect(api_client).not_to receive(:send_check)

      subject.push_checks ["VFI"]
    end

    it "does not push an adjustment if one has already been made" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI", intacct_adjustment_key: "ADJ-KEY"
      p = IntacctPayable.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI", intacct_key: "KEY", intacct_upload_date: Time.zone.now, payable_type: IntacctPayable::PAYABLE_TYPE_BILL

      expect(api_client).to receive(:send_check).with c1, false

      subject.push_checks ["VFI"]
    end
  end

  describe "run_schedulable" do
    subject { described_class }

    it "calls run with company list" do
      expect_any_instance_of(described_class).to receive(:run).with(['A', 'B'])
      subject.run_schedulable JSON.parse('{"companies":["A", "B"]}')
    end

    it "raises an error if no companies are given" do
      expect {subject.run_schedulable JSON.parse('{}')}.to raise_error(/companies/)
    end

    it "raises an error if non -array companies are given" do
      expect {subject.run_schedulable JSON.parse('{"companies": "Test"}')}.to raise_error(/array/)
    end

    it "raises an error if blank array is given" do
      expect {subject.run_schedulable JSON.parse('{"companies": []}')}.to raise_error(/companies/)
    end
  end

  describe "run" do
    it "pushes checks, receivables, and payables" do
      expect(subject).to receive(:push_checks).with(["A", "B"])
      expect(subject).to receive(:push_receivables).with(["A", "B"])
      expect(subject).to receive(:push_payables).with(["A", "B"])

      subject.run ["A", "B"]
    end

    it "suppresses receivables and payables if only_checks flag is utilized" do
      expect(subject).to receive(:push_checks).with(["A", "B"])
      expect(subject).not_to receive(:push_receivables)
      expect(subject).not_to receive(:push_payables)

      subject.run ["A", "B"], checks_only: true
    end

    it "suppresses checks if only_invoices flag is utilized" do
      expect(subject).not_to receive(:push_checks)
      expect(subject).to receive(:push_receivables).with(["A", "B"])
      expect(subject).to receive(:push_payables).with(["A", "B"])

      subject.run ["A", "B"], invoices_only: true
    end
  end
end
