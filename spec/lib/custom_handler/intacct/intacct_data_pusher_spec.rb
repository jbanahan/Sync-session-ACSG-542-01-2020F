require 'open_chain/custom_handler/intacct/intacct_data_pusher'

describe OpenChain::CustomHandler::Intacct::IntacctDataPusher do

  subject { described_class.new api_client }

  let (:api_client) { instance_double(OpenChain::CustomHandler::Intacct::IntacctClient) }

  describe "push_payable" do
    let (:payable) { IntacctPayable.create! vendor_number: "Vendor", company: "C", bill_number: "Bill" }

    it "sends given payable" do
      expect(Lock).to receive(:db_lock).with(payable).and_yield
      expect(api_client).to receive(:send_payable).with(payable, [])
      subject.push_payable payable
    end

    it "sends payables with checks" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill"
      c2 = IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_payable_id: payable.id

      expect(api_client).to receive(:send_payable).with(payable, [c1, c2])

      subject.push_payable payable
      payable.reload
      expect(payable.intacct_checks.size).to eq 2
      expect(payable.intacct_checks).to include c1
      expect(payable.intacct_checks).to include c2
    end

    it "does not include checks associated with another payable" do
      IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_payable_id: -1

      expect(api_client).to receive(:send_payable).with(payable, [])

      subject.push_payable payable
    end

    it "does not include checks that already have an adjustment associated with them" do
      IntacctCheck.create! vendor_number: "Vendor", company: 'C', bill_number: "Bill", intacct_adjustment_key: "ADJ-123"

      expect(api_client).to receive(:send_payable).with(payable, [])

      subject.push_payable payable
    end

    it "skips payables that have been sent after being reloaded by the Lock.db_lock call" do
      expect(Lock).to receive(:db_lock) do |&block|
        payable.update! intacct_upload_date: Time.zone.now
        block.call
      end
      expect(api_client).not_to receive(:send_payable)

      subject.push_payable payable
    end

    it "skips payables that have errors after being reloaded by the Lock.db_lock call" do
      expect(Lock).to receive(:db_lock) do |&block|
        payable.update! intacct_errors: "Error"
        block.call
      end
      expect(api_client).not_to receive(:send_payable)

      subject.push_payable payable
    end
  end

  describe "push_payables" do
    it "pushes payables to intacct that have not already been sent or errored and are for the company specified" do
      IntacctPayable.create! intacct_upload_date: Time.zone.now, company: "C"
      IntacctPayable.create! intacct_errors: "Error!", company: "C"
      p3 = IntacctPayable.create! vendor_number: "Vendor", company: "C"
      IntacctPayable.create! vendor_number: "Vendor", company: "A"

      expect(subject).to receive(:push_payable).with(p3)

      subject.push_payables ["C"]
    end

    it "handles an error in payable upload" do
      p = IntacctPayable.create! company: "C"
      error = StandardError.new "Error"
      expect(subject).to receive(:push_payable).with(p).and_raise error
      expect(error).to receive(:log_me).with ["Failed to upload Intacct Payable id #{p.id}."]

      subject.push_payables ["C"]
    end
  end

  describe "push_receivable" do
    let (:receivable) { IntacctReceivable.create! customer_number: "CUST", company: "C" }

    it "pushes receivable to intacct" do
      expect(api_client).to receive(:send_receivable).with receivable
      expect(Lock).to receive(:db_lock).and_yield

      subject.push_receivable receivable
    end

    it "skips receivables that have been sent after being reloaded by the Lock.db_lock call" do
      expect(Lock).to receive(:db_lock) do |&block|
        receivable.update! intacct_upload_date: Time.zone.now
        block.call
      end
      expect(api_client).not_to receive(:send_receivable)

      subject.push_receivable receivable
    end

    it "skips receivables that have errors after being reloaded by the Lock.db_lock call" do
      expect(Lock).to receive(:db_lock) do |&block|
        receivable.update! intacct_errors: "Error"
        block.call
      end
      expect(api_client).not_to receive(:send_receivable)

      subject.push_receivable receivable
    end
  end

  describe "push_receivables" do
    it "pushes receivables to intacct that have not already been sent or errored" do
      IntacctReceivable.create! intacct_upload_date: Time.zone.now, company: "C"
      IntacctReceivable.create! intacct_errors: "Error!", company: "C"
      r3 = IntacctReceivable.create! customer_number: "CUST", company: "C"
      IntacctReceivable.create! customer_number: "CUST", company: "A"

      expect(subject).to receive(:push_receivable).with(r3)

      subject.push_receivables ["C"]
    end

    it "handles error in receivable upload" do
      r = IntacctReceivable.create! company: "C"
      error = StandardError.new "Error"
      expect(subject).to receive(:push_receivable).with(r).and_raise error
      expect(error).to receive(:log_me).with ["Failed to upload Intacct Receivable id #{r.id}."]

      subject.push_receivables ["C"]
    end
  end

  describe "push_check" do
    let (:check) { IntacctCheck.create! vendor_number: "Vendor", bill_number: '123A', company: "VFI" }
    let (:payable) do
      IntacctPayable.create!(vendor_number: "Vendor", bill_number: '123A', company: "VFI", intacct_key: "KEY",
                             intacct_upload_date: Time.zone.now, payable_type: IntacctPayable::PAYABLE_TYPE_BILL)
    end

    it "sends check to intacct" do
      expect(Lock).to receive(:db_lock).with(check).and_yield
      expect(api_client).to receive(:send_check).with check, false

      subject.push_check check
    end

    it "sends checks issued after the payable to intacct" do
      payable
      expect(api_client).to receive(:send_check).with check, true
      subject.push_check check
    end

    it "does not push an adjustment if one has already been made" do
      check.update! intacct_adjustment_key: "ADJ-KEY"
      payable
      expect(api_client).to receive(:send_check).with check, false
      subject.push_check check
    end
  end

  describe "push_checks" do
    it "pushes checks to intacct" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: "C"
      IntacctCheck.create! vendor_number: "Vendor", intacct_errors: "Error", company: "C"
      IntacctCheck.create! vendor_number: "Vendor", intacct_upload_date: Time.zone.now, company: "C"
      IntacctCheck.create! vendor_number: "Vendor", company: "A"

      expect(subject).to receive(:push_check).with c1

      subject.push_checks ["C"]
    end

    it "handles errors in push_check" do
      c1 = IntacctCheck.create! vendor_number: "Vendor", company: "C"
      error = StandardError.new
      expect(error).to receive(:log_me).with(["Failed to upload Intacct Check id #{c1.id}."])
      expect(subject).to receive(:push_check).with(c1).and_raise error

      subject.push_checks ["C"]
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

  describe "push_billing_export_data" do
    subject { described_class }

    let! (:receivable_1) do
      rec1 = export.intacct_receivables.build invoice_number: "REC1"
      rec1.intacct_receivable_lines.build broker_file: "R1"
      rec1
    end

    let! (:receivable_2) do
      rec2 = export.intacct_receivables.build invoice_number: "REC2"
      rec2.intacct_receivable_lines.build broker_file: "R2"
      rec2
    end

    let! (:payable_1) do
      pay1 = export.intacct_payables.build bill_number: "PAY1"
      pay1.intacct_payable_lines.build broker_file: "P1", freight_file: "F1"
      pay1
    end

    let! (:payable_2) do
      pay2 = export.intacct_payables.build bill_number: "PAY2"
      pay2.intacct_payable_lines.build broker_file: "P2"
      pay2
    end

    let (:export) { IntacctAllianceExport.new }

    it "pushes export data to intacct" do
      expect_any_instance_of(described_class).to receive(:push_dimension).with("Broker File", "R1")
      expect_any_instance_of(described_class).to receive(:push_dimension).with("Broker File", "R2")
      expect_any_instance_of(described_class).to receive(:push_dimension).with("Broker File", "P1")
      expect_any_instance_of(described_class).to receive(:push_dimension).with("Broker File", "P2")
      expect_any_instance_of(described_class).to receive(:push_dimension).with("Freight File", "F1")

      expect_any_instance_of(described_class).to receive(:push_receivable).with(receivable_1)
      expect_any_instance_of(described_class).to receive(:push_receivable).with(receivable_2)
      expect_any_instance_of(described_class).to receive(:push_payable).with(payable_1)
      expect_any_instance_of(described_class).to receive(:push_payable).with(payable_2)

      subject.push_billing_export_data export
    end

    it "looks up export if a numeric is given" do
      expect(IntacctAllianceExport).to receive(:where).with(id: 1).and_return [export]

      expect_any_instance_of(described_class).to receive(:push_dimension).with("Broker File", "R1")
      expect_any_instance_of(described_class).to receive(:push_dimension).with("Broker File", "R2")
      expect_any_instance_of(described_class).to receive(:push_dimension).with("Broker File", "P1")
      expect_any_instance_of(described_class).to receive(:push_dimension).with("Broker File", "P2")
      expect_any_instance_of(described_class).to receive(:push_dimension).with("Freight File", "F1")

      expect_any_instance_of(described_class).to receive(:push_receivable).with(receivable_1)
      expect_any_instance_of(described_class).to receive(:push_receivable).with(receivable_2)
      expect_any_instance_of(described_class).to receive(:push_payable).with(payable_1)
      expect_any_instance_of(described_class).to receive(:push_payable).with(payable_2)

      subject.push_billing_export_data 1
    end
  end
end
