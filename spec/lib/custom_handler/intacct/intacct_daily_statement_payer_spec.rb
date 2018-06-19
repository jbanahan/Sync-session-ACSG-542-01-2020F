describe OpenChain::CustomHandler::Intacct::IntacctDailyStatementPayer do

  let (:intacct_client) {
    instance_double(OpenChain::CustomHandler::Intacct::IntacctClient)
  }

  subject {
    described_class.new intacct_client: intacct_client
  }

  let (:invoice) {
    invoice = BrokerInvoice.new invoice_number: "INV_NUM"
    line = BrokerInvoiceLine.new charge_code: "0001", charge_amount: BigDecimal.new("1.50")
    invoice.broker_invoice_lines << line
    invoice
  }

  let (:entry) {
    e = Entry.new broker_reference: "BROK_REF"    
    e.broker_invoices << invoice
    e
  }

  let (:credit_invoice) {
    invoice = BrokerInvoice.new invoice_number: "INV_NUM_CREDIT"
    line = BrokerInvoiceLine.new charge_code: "0001", charge_amount: BigDecimal.new("-1.50")
    invoice.broker_invoice_lines << line
    invoice
  }


  let (:daily_statement) {
    s = DailyStatement.new statement_number: "STATEMENT_NO", paid_date: Date.new(2018, 4, 1)
    e = DailyStatementEntry.new broker_reference: "BROK_REF", total_amount: BigDecimal("1.50")
    e.entry = entry
    s.daily_statement_entries << e

    s
  }

  def list_response_element recordno
    REXML::Document.new("<APBILL><RECORDNO>#{recordno}</RECORDNO></APBILL>").root
  end

  def read_object_response obj
    xml = "
<APBILL>
  <RECORDNO>#{obj[:record_no]}</RECORDNO>
  <RECORDID>#{obj[:record_id]}</RECORDID>
  <TOTALENTERED>#{obj[:total_entered]}</TOTALENTERED>
  <TOTALDUE>#{obj[:total_due]}</TOTALDUE>
  <WHENPAID>#{obj[:when_paid]}</WHENPAID>
  <APBILLITEMS>
    "
    Array.wrap(obj[:ap_bill_items]).each do |item|
      xml += "

      <apbillitem>
        <RECORDNO>#{item[:record_no]}</RECORDNO>
        <AMOUNT>#{item[:amount]}</AMOUNT>
        <CLASSID>#{item[:broker_reference]}</CLASSID>
      </apbillitem>
      "
    end
    xml += "
  </APBILLITEMS>
</APBILL>"

    REXML::Document.new(xml).root
  end

  describe "pay_statement" do

    let (:ap_bill) {
      {record_no: 1, record_id: "INV_NUM", total_entered: "1.50", total_due: "1.50", when_paid: "", 
        ap_bill_items: [
          {record_no: 101, amount: "1.50", broker_reference: "BROK_REF"}
        ]
      }
    }

    let (:ap_bill_credit) {
      {record_no: 2, record_id: "INV_NUM_CREDIT", total_entered: "-1.50", total_due: "-1.50", when_paid: "", 
        ap_bill_items: [
          {record_no: 201, amount: "-1.50", broker_reference: "BROK_REF"}
        ]
      }
    }

    def expect_standard
      expect(intacct_client).to receive(:sanitize_query_parameter_value).with("INV_NUM").and_return "INV_NUM"
      expect(intacct_client).to receive(:list_objects).with('vfc', 'APBILL', "VENDORID = 'VU160' AND RECORDID IN ('INV_NUM')", fields: ["RECORDNO"]).and_return [list_response_element("1")]
      expect(intacct_client).to receive(:read_object).with('vfc', 'APBILL', ["1"]).and_return [read_object_response(ap_bill)]
    end

    def expect_credit
      entry.broker_invoices << credit_invoice
      expect(intacct_client).to receive(:sanitize_query_parameter_value).with("INV_NUM").and_return "INV_NUM"
      expect(intacct_client).to receive(:sanitize_query_parameter_value).with("INV_NUM_CREDIT").and_return "INV_NUM_CREDIT"
      expect(intacct_client).to receive(:list_objects).with('vfc', 'APBILL', "VENDORID = 'VU160' AND RECORDID IN ('INV_NUM','INV_NUM_CREDIT')", fields: ["RECORDNO"]).and_return [list_response_element("1"), list_response_element("2")]
      expect(intacct_client).to receive(:read_object).with('vfc', 'APBILL', ["1", "2"]).and_return [read_object_response(ap_bill), read_object_response(ap_bill_credit)]

    end

    it "pays a daily_statement" do
      expect_standard
      payment = nil
      expect(subject).to receive(:post_payment) do |p|
        payment = p
      end

      errors = subject.pay_statement daily_statement
      expect(errors).to be_nil
      expect(payment).not_to be_nil

      expect(payment.financial_entity).to eq "TD Bank Duty"
      expect(payment.payment_method).to eq "EFT"
      expect(payment.vendor_id).to eq "VU160"
      expect(payment.document_number).to eq "STATEMENT_NO"
      expect(payment.currency).to eq "USD"
      expect(payment.description).to eq "STATEMENT_NO"
      expect(payment.payment_date).to eq Date.new(2018, 4, 1)

      expect(payment.payment_details.length).to eq 1

      item = payment.payment_details.first
      expect(item.bill_record_no).to eq 1
      expect(item.bill_line_id).to eq 101
      expect(item.bill_amount).to eq BigDecimal("1.50")
    end

    it "pays a daily statement with a credit" do
      expect_credit
      payment = nil
      expect(subject).to receive(:post_payment) do |p|
        payment = p
      end

      daily_statement.daily_statement_entries.first.total_amount = 0

      errors = subject.pay_statement daily_statement
      expect(errors).to be_nil
      expect(payment).not_to be_nil

      expect(payment.financial_entity).to eq "TD Bank Duty"
      expect(payment.payment_method).to eq "EFT"
      expect(payment.vendor_id).to eq "VU160"
      expect(payment.document_number).to eq "STATEMENT_NO"
      expect(payment.currency).to eq "USD"
      expect(payment.description).to eq "STATEMENT_NO"
      expect(payment.payment_date).to eq Date.new(2018, 4, 1)

      expect(payment.payment_details.length).to eq 1

      item = payment.payment_details.first
      expect(item.bill_record_no).to eq 1
      expect(item.bill_line_id).to eq 101
      expect(item.credit_amount).to eq BigDecimal("1.50")
      expect(item.credit_bill_record_no).to eq 2
      expect(item.credit_bill_line_id).to eq 201
    end

    it "uses monthly statement number if present" do
      daily_statement.monthly_statement = MonthlyStatement.new statement_number: "MONTHLY", paid_date: Date.new(2018, 5, 1)
      expect_standard
      payment = nil
      expect(subject).to receive(:post_payment) do |p|
        payment = p
      end

      errors = subject.pay_statement daily_statement
      expect(errors).to be_nil
      expect(payment).not_to be_nil

      expect(payment.description).to eq "MONTHLY"
      expect(payment.payment_date).to eq Date.new(2018, 5, 1)
    end

    it "does not error for Warehouse Entries (Type 21) where the billed amount matches the total statement amount minus duty" do
      expect(subject).to receive(:post_payment)
      expect_standard
      
      entry.entry_type = 21
      dse = daily_statement.daily_statement_entries.first
      dse.total_amount = 5
      dse.duty_amount = 3.5
      
      expect(subject.pay_statement daily_statement).to be_blank
    end

    it "skips broker invoices with duty paid direct lines on them" do
      # The only time this situation comes up is when an invoice has been billed incorrectly w/ a Duty Paid Direct
      # and then rebilled, so by adding a second broker invoice w/ a duty direct code (0099) we can show that it's
      # being skipped and not counted when trying to query Intacct.
      direct = BrokerInvoice.new(invoice_number: "INV_NUMA")
      direct.broker_invoice_lines << BrokerInvoiceLine.new(charge_code: "0001", charge_amount: BigDecimal.new("1.50"))
      direct.broker_invoice_lines << BrokerInvoiceLine.new(charge_code: "0099", charge_amount: BigDecimal.new("1.50"))
      entry.broker_invoices << direct

      expect_standard
      expect(subject).to receive(:post_payment)
      expect(subject.pay_statement daily_statement).to be_blank
    end

    context "error handling" do

      it "validates statement amount vs invoice amount" do
        invoice.broker_invoice_lines.first.charge_amount = BigDecimal("1.00")
        ap_bill[:total_entered] = BigDecimal("1.00")
        ap_bill[:total_due] = BigDecimal("1.00")
        ap_bill[:ap_bill_items].first[:amount] = BigDecimal("1.00")

        expect_standard
        errors = subject.pay_statement daily_statement
        expect(errors).to eq ["File # BROK_REF shows $1.00 billed in VFI Track but $1.50 on the statement."]
      end

      it "validates intacct data vs. invoice amount / statement" do
        ap_bill[:total_entered] = BigDecimal("1.00")
        ap_bill[:total_due] = BigDecimal("1.00")
        ap_bill[:ap_bill_items].first[:amount] = BigDecimal("1.00")

        expect_standard
        errors = subject.pay_statement daily_statement
        expect(errors).to eq [
          "Invoice # INV_NUM shows $1.50 duty in VFI Track vs. $1.00 in Intacct.", 
          "File # BROK_REF shows $1.00 billed in Intacct but $1.50 on the statement."]
      end

      it "validates broker invoice data exists for statements" do
        entry.broker_invoices = []
        errors = subject.pay_statement daily_statement
        expect(errors).to eq ["File # BROK_REF has no broker invoice information in VFI Track."]
      end

      it "validates AP data exists for statements in intacct" do
        #Just change the invoice number of the bill returned from intacct
        ap_bill[:record_id] = "INV"
        expect_standard
        errors = subject.pay_statement daily_statement
        expect(errors).to eq ["Invoice # INV_NUM is missing from Intacct."]
      end

      it "errors if invoice has already been paid in Intacct" do
        ap_bill[:when_paid] = Date.new(2018,4,1)
        expect_standard
        errors = subject.pay_statement daily_statement
        expect(errors).to eq ["Invoice # INV_NUM has already been paid in Intacct."]
      end

      it "errors if credit invoice doesn't line up with debit" do
        # Have to make all the invoice amoutns internally consistent...otherwise other errors are tripped.
        credit_invoice.broker_invoice_lines.first.charge_amount = BigDecimal("-1.00")
        daily_statement.daily_statement_entries.first.total_amount = BigDecimal("0.50")
        ap_bill_credit[:total_entered] = BigDecimal("-1.00")
        ap_bill_credit[:total_due] = BigDecimal("-1.00")
        ap_bill_credit[:ap_bill_items].first[:amount] = BigDecimal("-1.00")

        expect_credit
        errors = subject.pay_statement daily_statement
        expect(errors).to eq ["Unable to apply credit for Intacct Bill INV_NUM_CREDIT amount of -$1.00.  No matching debit line found."]
      end

      it "errors for Warehouse Entries (Type 21) where the billed amount doesn't match the total statement amount minus duty" do
        expect_standard
        
        entry.entry_type = 21
        dse = daily_statement.daily_statement_entries.first
        dse.total_amount = 5
        dse.duty_amount = 4
        
        expect(subject.pay_statement daily_statement).to include "File # BROK_REF (Entry Type 21) shows $1.50 billed in VFI Track but a total amount (minus Duty) of $1.00 on the statement."
      end

    end
  end
end