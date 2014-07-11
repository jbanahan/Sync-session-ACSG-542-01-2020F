require 'spec_helper'
require 'open_chain/report/intacct_exception_report'

describe OpenChain::Report::IntacctExceptionReport do

  before :each do
    MasterSetup.any_instance.stub(:request_host).and_return "localhost"
  end

  def get_emailed_worksheet name, mail = ActionMailer::Base.deliveries.pop
    fail("Expected at least one mail message.") unless mail
    at = mail.attachments["Intacct Integration Errors #{Time.zone.now.strftime("%m-%d-%Y")}.xls"]
    wb = Spreadsheet.open(StringIO.new(at.read))
    wb.worksheets.find {|s| s.name == name}
  end

  describe "run" do

    it "emails receivable and payable errors to given addresses" do
      r = IntacctReceivable.create! company: 'A', customer_number: 'Cust', invoice_number: "Inv", invoice_date: Time.zone.now, intacct_errors: "Errors"

      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', bill_number: "Bill", bill_date: Time.zone.now, intacct_errors: "Errors"
      p.intacct_payable_lines.create! customer_number: "Cust"

      described_class.new.run ['A', 'B'], ['me@there.com']
      mail = ActionMailer::Base.deliveries.pop
      expect(mail).not_to be_nil
      expect(mail.to).to eq ["me@there.com"]
      expect(mail.subject).to eq "Intacct Integration Errors #{Time.zone.now.strftime("%m/%d/%Y")}"
      at = mail.attachments["Intacct Integration Errors #{Time.zone.now.strftime("%m-%d-%Y")}.xls"]
      expect(at).not_to be_nil

      wb = Spreadsheet.open(StringIO.new(at.read))

      sheet = wb.worksheets.find {|s| s.name == "Receivable Errors"}

      expect(sheet.row(0)).to eq ["Clear Error", "Intacct Company", "Customer", "Invoice Number", "Invoice Date", "Suggested Fix", "Actual Intacct Error"]
      expect(sheet.row(1)).to eq ["Clear This Error", "A", "Cust", "Inv", excel_date(r.invoice_date.to_date), "Unknown Error. Contact support@vandegriftinc.com to resolve error.", "Errors"]
      expect(sheet.row(1)[0]).to eq Spreadsheet::Link.new(XlsMaker.excel_url("/intacct_receivables/#{r.id}/clear"), "Clear This Error")

      sheet = wb.worksheets.find {|s| s.name == "Payable Errors"}

      expect(sheet.row(0)).to eq ["Clear Error", "Intacct Company", "Customer", "Vendor", "Bill Number", "Bill Date", "Suggested Fix", "Actual Intacct Error"]
      expect(sheet.row(1)).to eq ["Clear This Error", "A", "Cust", "Vend", "Bill", excel_date(p.bill_date.to_date), "Unknown Error. Contact support@vandegriftinc.com to resolve error.", "Errors"]
      expect(sheet.row(1)[0]).to eq Spreadsheet::Link.new(XlsMaker.excel_url("/intacct_payables/#{r.id}/clear"), "Clear This Error")
    end

    it "does nothing if no rows are returned in either report" do
      described_class.new.run ['A', 'B'], ['me@there.com']
      expect(ActionMailer::Base.deliveries.pop).to be_nil
    end

    it "recognizes Receivable invalid customer errors" do
      r = IntacctReceivable.create! company: 'A', customer_number: "Cust", intacct_errors: "Description 2: Invalid Customer"
      described_class.new.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Receivable Errors"
      
      expect(sheet.row(1)[5]).to eq "Create Customer account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Receivable Date Due customer errors" do
      r = IntacctReceivable.create! company: 'A', customer_number: "Cust", intacct_errors: "Description 2: Required field Date Due is missing"
      described_class.new.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Receivable Errors"
      
      expect(sheet.row(1)[5]).to eq "Create Customer account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Receivable retry errors" do
      r = IntacctReceivable.create! company: 'A', customer_number: "Cust", intacct_errors: "BL01001973 XL03000009"
      described_class.new.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Receivable Errors"
      
      expect(sheet.row(1)[5]).to eq "Temporary Upload Error. Click 'Clear This Error' link to try again."
    end

    it "recognizes Receivable invalid customer errors" do
      r = IntacctReceivable.create! company: 'A', customer_number: "Cust", intacct_errors: "Description 2: Invalid Vendor 'Test' specified."
      described_class.new.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Receivable Errors"
      
      expect(sheet.row(1)[5]).to eq "Create Vendor account Test in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Payable missing vendor errors" do
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', intacct_errors: "Description 2: Invalid Vendor"

      described_class.new.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Payable Errors"
      
      expect(sheet.row(1)[6]).to eq "Create Vendor account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Payable missing vendor terms errors" do
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', intacct_errors: "Failed to retrieve Terms for Vendor"

      described_class.new.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Payable Errors"
      
      expect(sheet.row(1)[6]).to eq "Create Vendor account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Payable invalid customer errors" do
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', intacct_errors: "Description 2: Invalid Customer"
      p.intacct_payable_lines.create! customer_number: "Cust"

      described_class.new.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Payable Errors"
      
      expect(sheet.row(1)[6]).to eq "Create Customer account in Intacct."
    end

    it "recognizes Payable retry errors" do
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', intacct_errors: "BL01001973 XL03000009"

      described_class.new.run ['A'], ['me@there.com']
      sheet = get_emailed_worksheet "Payable Errors"
      expect(sheet.row(1)[6]).to eq "Temporary Upload Error. Click 'Clear This Error' link to try again."
    end
  end

  describe "run_schedulable" do
    it "runs with passed in options" do
      r = IntacctReceivable.create! company: 'A', customer_number: 'Cust', invoice_number: "Inv", invoice_date: Time.zone.now, intacct_errors: "Errors"
      p = IntacctPayable.create! company: 'A', vendor_number: 'Vend', bill_number: "Bill", bill_date: Time.zone.now, intacct_errors: "Errors"

      described_class.run_schedulable({'email_to'=>["me@there.com"], 'companies'=>['A']})

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["me@there.com"]
      expect(get_emailed_worksheet "Receivable Errors", mail).not_to be_nil
      expect(get_emailed_worksheet "Payable Errors", mail).not_to be_nil
    end

    it "raises an error if email is missing" do
      expect {described_class.run_schedulable({'companies'=>['A']})}.to raise_error
    end

    it "raises an error if email blank" do
      expect {described_class.run_schedulable({'email_to'=>[], 'companies'=>['A']})}.to raise_error
    end

    it "raises an error if companies is missing" do
      expect {described_class.run_schedulable({'email_to'=>["me@there.com"]})}.to raise_error
    end
  end
end