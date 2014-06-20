require 'spec_helper'
require 'open_chain/custom_handler/intacct/intacct_invoice_details_parser'

describe OpenChain::CustomHandler::Intacct::IntacctInvoiceDetailsParser do

  before :each do
    @line = {
      'file number'=>"123", 'suffix'=>"A", 'invoice number'=>"123A", 'freight file number'=>"F123", 'customer'=>"CUST", 'invoice date'=>"20140101",
      'currency'=>"USD", 'charge amount'=>"12.50", 'charge code'=>"0500", 'charge description'=>"CD", 'broker file number'=>"B123", 'vendor'=>"VEN",
      'vendor reference'=>"VEN REF", 'line division'=>"1", 'header division'=>"1", "check number" => "159", "bank number" => "111", "check date" => "20140401",
      'print'=>"Y"
    }
    @p = described_class.new

    @export = IntacctAllianceExport.create! file_number: @line['file number'], suffix: @line['suffix']
  end

  describe "create_receivable" do
    it "creates a vfi receivable object" do
      r = @p.create_receivable [@line, @line], true

      expect(r.persisted?).to be_true
      expect(r.receivable_type).to eq "VFI Sales Invoice"
      expect(r.company).to eq "vfc"
      expect(r.invoice_number).to eq @line['invoice number']
      expect(r.invoice_date).to eq Date.strptime @line['invoice date'], "%Y%m%d"
      expect(r.customer_number).to eq @line['customer']
      expect(r.currency).to eq @line['currency']
      
      expect(r.intacct_receivable_lines).to have(2).items

      # Don't bother checking both lines, since the same exact value was used for both
      l = r.intacct_receivable_lines.first
      expect(l.location).to eq @line['line division']
      expect(l.amount).to eq BigDecimal.new(@line["charge amount"])
      expect(l.charge_code).to eq @line['charge code']
      expect(l.charge_description).to eq @line['charge description']
      expect(l.broker_file).to eq @line['broker file number']
      expect(l.freight_file).to eq @line['freight file number']
      expect(l.line_of_business).to eq "Brokerage"
      expect(l.vendor_number).to eq @line['vendor']
      expect(l.vendor_reference).to eq @line['vendor reference']
      expect(l.location).to eq @line["line division"]

      @export.reload
      expect(@export.data_received_date.to_date).to eq Time.zone.now.to_date
    end

    it "creates a vfi receivable object with LMD lines" do
      @line["line division"] = "11"

      r = @p.create_receivable [@line], true
      expect(r.intacct_receivable_lines).to have(1).item

      l = r.intacct_receivable_lines.first
      expect(l.location).to eq @line['header division']
    end

    it "creates a credit note object" do
      l2 = @line.dup
      l2['charge amount'] = "-25"

      r = @p.create_receivable [@line, l2], true
      expect(r.persisted?).to be_true
      expect(r.receivable_type).to eq "VFI Credit Note"

      # Credit memos invert the charge amounts (negative amounts are positive / positive are negative)
      expect(r.intacct_receivable_lines.first.amount).to eq (BigDecimal.new(@line['charge amount']) * -1)
      expect(r.intacct_receivable_lines.second.amount).to eq (BigDecimal.new(l2['charge amount']) * -1)
    end

    it "creates an lmd receivable from brokerage file data" do
      @line['line division'] = "11"
      r = @p.create_receivable [@line, @line]

      # Just check the differences in fields between lmd and vfc receivables
      expect(r.customer_number).to eq "VANDE"
      expect(r.company).to eq "lmd"
      expect(r.receivable_type).to eq "LMD Sales Invoice"
      expect(r.invoice_number).to eq @line['freight file number']
      expect(r.intacct_receivable_lines.first.line_of_business).to eq 'Freight'
      expect(r.intacct_receivable_lines.first.location).to eq @line["line division"]
    end

    it "creates an lmd receivable from an LMD file" do
      @line['header division'] = "11"
      @line['line division'] = "11"
      r = @p.create_receivable [@line, @line]

      # Just check the differences in fields between lmd and vfc receivables
      expect(r.customer_number).to eq @line["customer"]
      expect(r.company).to eq "lmd"
      expect(r.receivable_type).to eq "LMD Sales Invoice"
      expect(r.invoice_number).to eq @line['invoice number']
      expect(r.intacct_receivable_lines.first.line_of_business).to eq 'Freight'
    end

    it "creates an LMD credit note object" do
      @line['header division'] = "11"
      @line['line division'] = "11"
      l2 = @line.dup
      l2['charge amount'] = "-25"

      r = @p.create_receivable [@line, l2], true
      expect(r.persisted?).to be_true
      expect(r.receivable_type).to eq "LMD Credit Note"

      # Credit memos invert the charge amounts (negative amounts are positive / positive are negative)
      expect(r.intacct_receivable_lines.first.amount).to eq (BigDecimal.new(@line['charge amount']) * -1)
      expect(r.intacct_receivable_lines.second.amount).to eq (BigDecimal.new(l2['charge amount']) * -1)
    end

    it "updates vfc receivables that have not been sent" do
      exists = IntacctReceivable.create! company: 'vfc', invoice_number: @line['invoice number'], customer_number: @line['customer'], intacct_errors: "errors"
      r = @p.create_receivable [@line, @line], true
      expect(r.id).to eq exists.id
      expect(r.intacct_errors).to be_nil
      # Make sure lines are deleted and recreated
      expect(r.intacct_receivable_lines).to have(2).items
    end

    it "updates lmd receivables from brokerage files that have not been sent" do
      @line['line division'] = "11"
      exists = IntacctReceivable.create! company: 'lmd', invoice_number: @line['freight file number'], customer_number: "VANDE", intacct_errors: "errors"
      r = @p.create_receivable [@line, @line]
      expect(r.id).to eq exists.id
      expect(r.intacct_errors).to be_nil
    end

    it "updates lmd receivables from LMD files that have not been sent" do
      @line['header division'] = "11"
      @line['line division'] = "11"
      exists = IntacctReceivable.create! company: 'lmd', invoice_number: @line['invoice number'], customer_number: @line['customer'], intacct_errors: "errors"
      r = @p.create_receivable [@line, @line]
      expect(r.id).to eq exists.id
      expect(r.intacct_errors).to be_nil
    end

    it "does not create a receivable if a vfc file already exists with an upload date and key" do
      IntacctReceivable.create! company: 'vfc', invoice_number: @line['invoice number'], customer_number: @line['customer'], intacct_upload_date: Time.zone.now, intacct_key: "Key"
      expect(@p.create_receivable [@line, @line], true).to be_nil
    end

    it "does not create an lmd receivable from a brokerage file if a file already exists with an upload date and key" do
      @line['line division'] = "11"
      IntacctReceivable.create! company: 'lmd', invoice_number: @line['freight file number'], customer_number: "VANDE", intacct_upload_date: Time.zone.now, intacct_key: "Key"
      expect(@p.create_receivable [@line, @line]).to be_nil
    end

    it "does not create an lmd receivable from an LMD file if a file already exists with an upload date and key" do
      @line['line division'] = "11"
      @line['header division'] = "11"
      IntacctReceivable.create! company: 'lmd', invoice_number: @line['invoice number'], customer_number: @line['customer'], intacct_upload_date: Time.zone.now, intacct_key: "Key"
      expect(@p.create_receivable [@line, @line]).to be_nil
    end

    it "finds alliance exports and creates receivables when alliance returns blank string for suffix" do
      @export.update_attributes! suffix: nil
      @line['suffix'] = "         "
      r = @p.create_receivable [@line], true
      expect(r).to be_persisted
    end

    it "uses customer and vendor xrefs when available" do
      @customer = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @line['customer']), value: "CUSTOMER", cross_reference_type: DataCrossReference::INTACCT_CUSTOMER_XREF
      @vendor = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @line['vendor']), value: "VENDOR", cross_reference_type: DataCrossReference::INTACCT_VENDOR_XREF

      r = @p.create_receivable [@line]
      expect(r.customer_number).to eq @customer.value
      expect(r.intacct_receivable_lines.first.vendor_number).to eq @vendor.value
    end
  end

  describe "create_payable" do
    before :each do
      @gl_account = DataCrossReference.create! key: @line['charge code'], value: "GLACCOUNT", cross_reference_type: DataCrossReference::ALLIANCE_CHARGE_TO_GL_ACCOUNT
      @bank = DataCrossReference.create! key: @line['bank number'], value: "INTACCT BANK", cross_reference_type: DataCrossReference::ALLIANCE_BANK_ACCOUNT_TO_INTACCT
      @bank_cash_account = DataCrossReference.create! key: @bank.value, value: "BANK CASH", cross_reference_type: DataCrossReference::INTACCT_BANK_CASH_GL_ACCOUNT
    end

    it "creates a vfc check payable" do
      p = @p.create_payable "VENDOR", [@line, @line]

      expect(p.persisted?).to be_true
      expect(p.company).to eq "vfc"
      expect(p.vendor_number).to eq "VENDOR"
      expect(p.vendor_reference).to be_nil
      expect(p.currency).to eq @line["currency"]
      expect(p.bill_number).to eq @line["invoice number"]
      expect(p.bill_date).to eq Date.strptime @line["invoice date"], "%Y%m%d"
      expect(p.check_number).to eq @line["check number"]
      expect(p.payable_type).to eq IntacctPayable::PAYABLE_TYPE_CHECK

      expect(p.intacct_payable_lines).to have(2).items
      # Only bother inspecting one line since we used same
      # data for both lines

      l = p.intacct_payable_lines.first
      expect(l.charge_code).to eq @line["charge code"]
      expect(l.gl_account).to eq @gl_account.value
      expect(l.amount).to eq BigDecimal.new(@line["charge amount"])
      expect(l.charge_description).to eq "#{@line["charge description"]} - #{@line["vendor reference"]}"
      expect(l.location).to eq @line["line division"]
      expect(l.line_of_business).to eq "Brokerage"
      expect(l.freight_file).to eq @line["freight file number"]
      expect(l.customer_number).to eq @line['customer']
      expect(l.broker_file).to eq @line['broker file number']
      expect(l.check_number).to eq @line["check number"]
      expect(l.bank_number).to eq @bank.value
      expect(l.check_date).to eq Date.strptime @line["check date"], "%Y%m%d"
      expect(l.bank_cash_gl_account).to eq @bank_cash_account.value

      @export.reload
      expect(@export.data_received_date.to_date).to eq Time.zone.now.to_date
    end

    it "creates vfc bill payable" do
      @line["check number"] = '0'
      p = @p.create_payable "VENDOR", [@line]

      expect(p.check_number).to be_nil
      expect(p.payable_type).to eq IntacctPayable::PAYABLE_TYPE_BILL
    end

    it "creates a vfc payable to lmd division" do
      p = @p.create_payable "LMD", [@line]

      expect(p.persisted?).to be_true
      expect(p.company).to eq "vfc"
      expect(p.vendor_number).to eq "LMD"
      expect(p.vendor_reference).to eq @line["freight file number"]
      expect(p.currency).to eq @line["currency"]
      expect(p.bill_number).to eq @line["invoice number"]
      expect(p.bill_date).to eq Date.strptime @line["invoice date"], "%Y%m%d"

      
      l = p.intacct_payable_lines.first
      expect(l.gl_account).to eq "2025"

      # Make sure the location is set to the header division for payables to lmd
      expect(l.location).to eq @line["header division"]
    end

    it "creates an LMD payable for division 11" do
      @line["header division"] = "11"

      p = @p.create_payable "LMD VENDOR", [@line]
      expect(p.persisted?).to be_true
      expect(p.company).to eq "lmd"
      expect(p.vendor_number).to eq "LMD VENDOR"
      expect(p.vendor_reference).to be_nil
      expect(p.currency).to eq @line["currency"]
      expect(p.bill_number).to eq @line["invoice number"]
      expect(p.bill_date).to eq Date.strptime @line["invoice date"], "%Y%m%d"

      l = p.intacct_payable_lines.first
      expect(l.charge_code).to eq @line["charge code"]
      expect(l.gl_account).to eq @gl_account.value
      expect(l.amount).to eq BigDecimal.new(@line["charge amount"])
      expect(l.charge_description).to eq "#{@line["charge description"]} - #{@line["vendor reference"]}"
      expect(l.location).to eq @line["line division"]
      expect(l.line_of_business).to eq "Freight"
      expect(l.freight_file).to eq @line["freight file number"]
      expect(l.customer_number).to eq @line['customer']
      expect(l.broker_file).to be_nil

      @export.reload
      expect(@export.data_received_date.to_date).to eq Time.zone.now.to_date
    end

    it "creates an LMD payable for division 12" do
      @line["header division"] = "12"

      p = @p.create_payable "LMD VENDOR", [@line]
      expect(p.persisted?).to be_true
      expect(p.company).to eq "lmd"
    end

    it "updates an existing payable that has not been sent" do
      exists = IntacctPayable.create! company: 'vfc', vendor_number: "VENDOR", bill_number: @line["invoice number"], payable_type: IntacctPayable::PAYABLE_TYPE_CHECK, check_number: @line["check number"], intacct_errors: "Error"

      p = @p.create_payable "VENDOR", [@line]
      expect(exists.id).to eq p.id
      expect(p.intacct_errors).to be_nil
      # Make sure lines are deleted and recreated
      expect(p.intacct_payable_lines).to have(1).item
    end

    it "skips payables that have already been sent" do
      IntacctPayable.create! company: 'vfc', vendor_number: "VENDOR", bill_number: @line["invoice number"], payable_type: IntacctPayable::PAYABLE_TYPE_CHECK, check_number: @line["check number"], intacct_upload_date: Time.zone.now, intacct_key: "KEY"
      expect(@p.create_payable "VENDOR", [@line]).to be_nil
    end

    it "finds alliance exports and creates payables when alliance returns blank string for suffix" do
      @export.update_attributes! suffix: nil
      @line['suffix'] = "         "
      p = @p.create_payable "VENDOR", [@line]
      expect(p).to be_persisted
    end

    it "uses customer and vendor xrefs when available" do
      @customer = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @line['customer']), value: "CUSTOMER", cross_reference_type: DataCrossReference::INTACCT_CUSTOMER_XREF
      @vendor = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @line['vendor']), value: "VENDOR", cross_reference_type: DataCrossReference::INTACCT_VENDOR_XREF

      p = @p.create_payable @line['vendor'], [@line]
      expect(p.vendor_number).to eq @vendor.value
      expect(p.intacct_payable_lines.first.customer_number).to eq @customer.value
    end

    it "uses Advanced Payment GL account if check has been logged already" do
     IntacctPayable.create! company: 'vfc', vendor_number: @line['vendor'], bill_number: @line["invoice number"], check_number: @line['check number'], payable_type: IntacctPayable::PAYABLE_TYPE_ADVANCED

     p = @p.create_payable @line['vendor'], [@line]
     expect(p.intacct_payable_lines.first.bank_cash_gl_account).to eq "2021"
    end
  end

  describe "extract_receivable_lines" do
    it "pulls out all vfc and lmd receivable lines from a result set for a broker invoice" do
      non_print = @line.dup
      non_print['print'] = "N"

      lmd_line1 = @line.dup
      lmd_line1['line division'] = "11"

      lmd_line2 = @line.dup
      lmd_line2['line division'] = "12"


      broker_receivables, lmd_receivables = @p.extract_receivable_lines [@line, non_print, lmd_line1, lmd_line2]
      expect(broker_receivables).to have(3).items
      expect(broker_receivables.first).to eq @line
      expect(broker_receivables.second).to eq lmd_line1
      expect(broker_receivables.third).to eq lmd_line2

      expect(lmd_receivables).to have(2).items
      expect(lmd_receivables.first).to eq lmd_line1
      expect(lmd_receivables.second).to eq lmd_line2
    end

    it "extracts receivables and payables from an lmd invoice file" do
      @line['header division'] = "11"

      line2 = @line.dup
      line2['header division'] = "12"

      broker_receivables, lmd_receivables = @p.extract_receivable_lines [@line, line2]
      expect(broker_receivables).to have(0).items
      expect(lmd_receivables).to have(2).items
    end
  end

  describe "extract_payable_lines" do
    it "pulls out all vfc lines from a result set for a broker invoice" do
      @line['payable'] = "Y"
      line2 = @line.dup
      line2['vendor'] = "VENDOR2"

      non_payable = line2.dup
      non_payable['payable'] = "N"

      lmd_line = @line.dup
      lmd_line['payable'] = "N"
      lmd_line['line division'] = "11"

      lmd_line2 = lmd_line.dup
      lmd_line2['line division'] = "12"

      broker_payable, lmd_payable = @p.extract_payable_lines [@line, line2, non_payable, lmd_line, lmd_line2]
      expect(broker_payable.keys).to have(3).items
      expect(broker_payable["#{@line["vendor"]}~#{@line["check number"]}~#{@line["bank number"]}~#{@line["check date"]}"]).to have(1).item
      expect(broker_payable["#{line2["vendor"]}~#{line2["check number"]}~#{line2["bank number"]}~#{line2["check date"]}"]).to have(1).item
      expect(broker_payable["LMD"]).to have(2).items

      expect(lmd_payable.keys).to have(0).items
    end

    it "pulls out all lmd payable lines from a result set for lmd invoices" do
      @line['payable'] = "Y"
      @line['header division'] = "11"
      line2 = @line.dup
      line2['vendor'] = "VENDOR2"
      line2['header division'] = "12"
      non_payable = line2.dup
      non_payable['payable'] = "N"

      broker_payable, lmd_payable = @p.extract_payable_lines [@line, line2, non_payable]
      expect(broker_payable.keys).to have(0).items
      expect(lmd_payable.keys).to have(2).items

      expect(lmd_payable["#{@line["vendor"]}~#{@line["check number"]}~#{@line["bank number"]}~#{@line["check date"]}"]).to have(1).item
      expect(lmd_payable["#{line2["vendor"]}~#{line2["check number"]}~#{line2["bank number"]}~#{line2["check date"]}"]).to have(1).item
    end
  end

  describe "parse" do

    it "parses a brokerage file result set into receivables and payables and saves them all" do
      # All the individual methods this method uses are tested on their own, this
      # is basically just an integration test to make sure all the methods are in fact used correctly.

      # Create a result set that will make brokerage receivable, lmd receivable, and brokerage payables
      line2 = @line.dup
      line2['payable'] = "Y"
      line2['print'] = "N"

      @line["line division"] = "11"

      # We should have enqueue a couple file number dimension send attempts
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:delay).exactly(2).times.and_return OpenChain::CustomHandler::Intacct::IntacctClient
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Broker File", @line["broker file number"], @line["broker file number"])
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Freight File", @line["freight file number"], @line["freight file number"])

      @p.parse [@line, line2]

      @export.reload

      receivables = @export.intacct_receivables
      expect(receivables).to have(2).items
      expect(receivables.find_all {|r| r.company == "lmd"}).to have(1).item
      # This line is basically just a check that the right flag is used by the parse method when creating
      # lmd recievables
      expect(receivables.find {|r| r.company == "lmd"}.invoice_number).to eq @line["freight file number"]
      expect(receivables.find_all {|r| r.company == "vfc"}).to have(1).item

      payables = @export.intacct_payables
      expect(payables).to have(2).items

      expect(payables.find_all {|p| p.vendor_number == "LMD"}).to have(1).item
      expect(payables.find_all {|p| p.vendor_number == line2['vendor']}).to have(1).item
    end

    it "parses an lmd file result set into receivables and payables and saves them all" do
      @line["header division"] = "11"
      @line["line division"] = "11"

      line2 = @line.dup
      line2['payable'] = "Y"
      line2['print'] = "N"

      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:delay).and_return OpenChain::CustomHandler::Intacct::IntacctClient
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Freight File", @line["freight file number"], @line["freight file number"])

      @p.parse [@line, line2]

      @export.reload
      receivables = @export.intacct_receivables
      expect(receivables).to have(1).item
      expect(receivables.first.company).to eq "lmd"
      # This line is basically just a check that the right flag is used by the parse method when creating
      # lmd recievables
      expect(receivables.first.invoice_number).to eq @line["invoice number"]
      
      payables = @export.intacct_payables
      expect(payables).to have(1).item
      expect(payables.first.vendor_number).to eq line2["vendor"]
    end

    it "creates multiple check payables for different checks to the same vendor on the same invoice" do
      @line["payable"] = "Y"
      @line["freight file number"] = ""
      line2 = @line.dup
      line2["check number"] = (@line["check number"].to_i + 1).to_s

      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:delay).and_return OpenChain::CustomHandler::Intacct::IntacctClient
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Broker File", @line["broker file number"], @line["broker file number"])

      @p.parse [@line, line2]

      @export.reload

      payables = @export.intacct_payables
      expect(payables).to have(2).items
      expect(payables.find {|p| p.check_number == @line["check number"]}).not_to be_nil
      expect(payables.find {|p| p.check_number == line2["check number"]}).not_to be_nil
    end

  end

  describe "parse_check_query_results" do

    before :each do
      @gl_account = DataCrossReference.create! key: @line['charge code'], value: "GLACCOUNT", cross_reference_type: DataCrossReference::ALLIANCE_CHARGE_TO_GL_ACCOUNT
      @bank = DataCrossReference.create! key: @line['bank number'], value: "INTACCT BANK", cross_reference_type: DataCrossReference::ALLIANCE_BANK_ACCOUNT_TO_INTACCT
      @bank_cash_account = DataCrossReference.create! key: @bank.value, value: "BANK CASH", cross_reference_type: DataCrossReference::INTACCT_BANK_CASH_GL_ACCOUNT
    end

    it "creates an advanced check payable" do
      @p.parse_advance_check_results [@line]

      p = IntacctPayable.where(bill_number: @line['invoice number']).first
      expect(p).not_to be_nil

      expect(p.payable_type).to eq IntacctPayable::PAYABLE_TYPE_ADVANCED

      expect(p.company).to eq "vfc"
      expect(p.vendor_number).to eq @line['vendor']
      expect(p.vendor_reference).to eq @line["vendor reference"]
      expect(p.currency).to eq @line["currency"]
      expect(p.bill_number).to eq @line["invoice number"]
      expect(p.bill_date).to eq Date.strptime @line["check date"], "%Y%m%d"
      expect(p.check_number).to eq @line["check number"]
      expect(p.payable_type).to eq IntacctPayable::PAYABLE_TYPE_ADVANCED

      expect(p.intacct_payable_lines).to have(1).item

      l = p.intacct_payable_lines.first
      expect(l.charge_code).to eq @line["charge code"]
      expect(l.gl_account).to eq "2021"
      expect(l.amount).to eq BigDecimal.new(@line["charge amount"])
      expect(l.charge_description).to eq "#{@line["charge description"]} - #{@line["vendor reference"]}"
      expect(l.location).to eq @line["line division"]
      expect(l.line_of_business).to eq "Brokerage"
      expect(l.freight_file).to eq @line["freight file number"]
      expect(l.customer_number).to eq @line['customer']
      expect(l.broker_file).to eq @line['broker file number']
      expect(l.check_number).to eq @line["check number"]
      expect(l.bank_number).to eq @bank.value
      expect(l.check_date).to eq Date.strptime @line["check date"], "%Y%m%d"
      expect(l.bank_cash_gl_account).to eq @bank_cash_account.value
    end

    it "does not create a payable if check already exists" do
      IntacctPayable.create! company: 'vfc', vendor_number: @line['vendor'], bill_number: @line['invoice number'], check_number: @line['check number'], payable_type: IntacctPayable::PAYABLE_TYPE_CHECK

      @p.parse_advance_check_results [@line]

      expect(IntacctPayable.where(payable_type: IntacctPayable::PAYABLE_TYPE_ADVANCED).first).to be_nil
    end

    it "updates an existing advanced payable" do
      p = IntacctPayable.create! company: 'vfc', vendor_number: @line['vendor'], bill_number: @line['invoice number'], check_number: @line['check number'], payable_type: IntacctPayable::PAYABLE_TYPE_ADVANCED, intacct_errors: "Errors"

      @p.parse_advance_check_results [@line]

      p.reload
      expect(p.intacct_errors).to be_nil
    end

    it "uses vendor and customer cross references" do
      @customer = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @line['customer']), value: "CUSTOMER", cross_reference_type: DataCrossReference::INTACCT_CUSTOMER_XREF
      @vendor = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @line['vendor']), value: "VENDOR", cross_reference_type: DataCrossReference::INTACCT_VENDOR_XREF

      @p.parse_advance_check_results [@line]
      p = IntacctPayable.first

      expect(p.vendor_number).to eq @vendor.value
      expect(p.intacct_payable_lines.first.customer_number).to eq @customer.value
    end

    it 'creates LMD advanced payable' do
      @line['header division'] = '11'

      @p.parse_advance_check_results [@line]
      p = IntacctPayable.first
      expect(p.company).to eq "lmd"
    end

    it "handles multiple check result lines" do
      line2 = @line.dup
      line2['check number'] = "0987"

      @p.parse_advance_check_results [@line, line2]

      expect(IntacctPayable.where(payable_type: IntacctPayable::PAYABLE_TYPE_ADVANCED).all).to have(2).items
    end
  end
end