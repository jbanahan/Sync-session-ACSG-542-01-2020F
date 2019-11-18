describe OpenChain::Report::IntacctExceptionReport do

  before :each do
    allow_any_instance_of(MasterSetup).to receive(:request_host).and_return "localhost"
  end

  def get_emailed_worksheet name, mail = ActionMailer::Base.deliveries.pop
    fail("Expected at least one mail message.") unless mail
    at = mail.attachments["Intacct Integration Errors #{Time.zone.now.strftime("%m-%d-%Y")}.xlsx"]
    wb = XlsxTestReader.new(StringIO.new(at.read))
    wb.raw_data(name)
  end

  describe "run" do

    it "emails receivable and payable errors to given addresses" do
      r = IntacctReceivable.create! company: 'A', customer_number: 'Cust', invoice_number: "Inv", invoice_date: Time.zone.now, intacct_errors: "Errors"
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', bill_number: "Bill", bill_date: Time.zone.now, intacct_errors: "Errors"
      p.intacct_payable_lines.create! customer_number: "Cust"
      c = IntacctCheck.create! company: 'A', customer_number: "Cust", vendor_number: 'Vend', bill_number: "Bill", check_date: Time.zone.now, check_number: '123', intacct_errors: "Errors"

      error_count = subject.run ['A', 'B'], ['me@there.com']
      expect(error_count).to eq 3
      mail = ActionMailer::Base.deliveries.pop
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["me@there.com"]
      expect(mail.subject).to eq "Intacct Integration Errors #{Time.zone.now.strftime("%m/%d/%Y")}"
      at = mail.attachments["Intacct Integration Errors #{Time.zone.now.strftime("%m-%d-%Y")}.xlsx"]
      expect(at).not_to be_nil

      wb = XlsxTestReader.new(StringIO.new(at.read)).raw_workbook_data

      sheet = wb["Receivable Errors"]

      expect(sheet[0]).to eq ["Clear Error", "Intacct Company", "Customer", "Invoice Number", "Invoice Date", "Suggested Fix", "Actual Intacct Error"]
      expect(sheet[1]).to eq ["Clear This Error", "A", "Cust", "Inv", r.invoice_date.to_date, "Unknown Error. Contact support@vandegriftinc.com to resolve error.", "Errors"]
      
      sheet = wb["Payable Errors"]

      expect(sheet[0]).to eq ["Clear Error", "Intacct Company", "Customer", "Vendor", "Bill Number", "Bill Date", "Suggested Fix", "Actual Intacct Error"]
      expect(sheet[1]).to eq ["Clear This Error", "A", "Cust", "Vend", "Bill", p.bill_date.to_date, "Unknown Error. Contact support@vandegriftinc.com to resolve error.", "Errors"]
      
      sheet = wb["Check Errors"]

      expect(sheet[0]).to eq ["Clear Error", "Intacct Company", "Customer", "Vendor", "Check Number", "Check Date", "Bill Number", "Suggested Fix", "Actual Intacct Error"]
      expect(sheet[1]).to eq ["Clear This Error", "A", "Cust", "Vend", "123", c.check_date.to_date, "Bill", "Unknown Error. Contact support@vandegriftinc.com to resolve error.", "Errors"]
    end

    it "does nothing if no rows are returned in either report" do
      subject.run ['A', 'B'], ['me@there.com']
      expect(ActionMailer::Base.deliveries.pop).to be_nil
    end

    it "recognizes Receivable invalid customer errors" do
      r = IntacctReceivable.create! company: 'A', customer_number: "Cust", intacct_errors: "Description 2: Invalid Customer"
      subject.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Receivable Errors"

      expect(sheet[1][5]).to eq "Create Customer account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Receivable Date Due customer errors" do
      r = IntacctReceivable.create! company: 'A', customer_number: "Cust", intacct_errors: "Description 2: Required field Date Due is missing"
      subject.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Receivable Errors"

      expect(sheet[1][5]).to eq "Create Customer account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Receivable retry errors" do
      r = IntacctReceivable.create! company: 'A', customer_number: "Cust", intacct_errors: "BL01001973 XL03000009"
      subject.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Receivable Errors"

      expect(sheet[1][5]).to eq "Temporary Upload Error. Click 'Clear This Error' link to try again."
    end

    it "recognizes Receivable invalid customer errors" do
      r = IntacctReceivable.create! company: 'A', customer_number: "Cust", intacct_errors: "Description 2: Invalid Vendor 'Test' specified."
      subject.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Receivable Errors"

      expect(sheet[1][5]).to eq "Create Vendor account Test in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Payable missing vendor errors" do
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', intacct_errors: "Description 2: Invalid Vendor"

      subject.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Payable Errors"

      expect(sheet[1][6]).to eq "Create Vendor account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Payable missing vendor terms errors" do
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', intacct_errors: "Failed to retrieve Terms for Vendor"

      subject.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Payable Errors"

      expect(sheet[1][6]).to eq "Create Vendor account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Payable invalid customer errors" do
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', intacct_errors: "Description 2: Invalid Customer"
      p.intacct_payable_lines.create! customer_number: "Cust"

      subject.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Payable Errors"

      expect(sheet[1][6]).to eq "Create Customer account in Intacct."
    end

    it "recognizes Payable retry errors" do
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', intacct_errors: "BL01001973 XL03000009"

      subject.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Payable Errors"
      expect(sheet[1][6]).to eq "Temporary Upload Error. Click 'Clear This Error' link to try again."
    end
  end

  describe "run_schedulable" do
    subject { described_class }
    
    it "runs with passed in options" do
      r = IntacctReceivable.create! company: 'A', customer_number: 'Cust', invoice_number: "Inv", invoice_date: Time.zone.now, intacct_errors: "Errors"
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', bill_number: "Bill", bill_date: Time.zone.now, intacct_errors: "Errors"
      c = IntacctCheck.create! company: 'A', customer_number: "Cust", vendor_number: 'Vend', bill_number: "Bill", check_date: Time.zone.now, check_number: '123', intacct_errors: "Errors"

      subject.run_schedulable({'email_to'=>["me@there.com"], 'companies'=>['A']})

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["me@there.com"]
      expect(get_emailed_worksheet "Receivable Errors", mail).not_to be_nil
      expect(get_emailed_worksheet "Payable Errors", mail).not_to be_nil
      expect(get_emailed_worksheet "Check Errors", mail).not_to be_nil
    end

    it "raises an error if email is missing" do
      expect {subject.run_schedulable({'companies'=>['A']})}.to raise_error(/email/)
    end

    it "raises an error if email blank" do
      expect {subject.run_schedulable({'email_to'=>[], 'companies'=>['A']})}.to raise_error(/email/)
    end

    it "raises an error if companies is missing" do
      expect {subject.run_schedulable({'email_to'=>["me@there.com"]})}.to raise_error(/company/)
    end
  end
end
