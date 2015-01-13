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

    @export = IntacctAllianceExport.create! file_number: @line['file number'], suffix: @line['suffix'], division: "1", ar_total: "12.50", ap_total: "12.50", customer_number: "C", invoice_date: Date.new(2014,1,1), export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE
  end

  describe "create_receivable" do
    it "creates a vfi receivable object" do
      r = @p.create_receivable @export, [@line, @line], true

      expect(r.persisted?).to be_true
      expect(r.receivable_type).to eq "VFI Sales Invoice"
      expect(r.company).to eq "vfc"
      expect(r.invoice_number).to eq @line['invoice number']
      expect(r.invoice_date).to eq @export.invoice_date
      expect(r.customer_number).to eq @export.customer_number
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

    end

    it "creates a vfi receivable object with LMD lines" do
      @line["line division"] = "11"

      r = @p.create_receivable @export, [@line], true
      expect(r.intacct_receivable_lines).to have(1).item

      l = r.intacct_receivable_lines.first
      expect(l.location).to eq @export.division
    end

    it "creates a credit note object" do
      l2 = @line.dup
      l2['charge amount'] = "-25"

      r = @p.create_receivable @export, [@line, l2], true
      expect(r.persisted?).to be_true
      expect(r.receivable_type).to eq "VFI Credit Note"

      # Credit memos invert the charge amounts (negative amounts are positive / positive are negative)
      expect(r.intacct_receivable_lines.first.amount).to eq (BigDecimal.new(@line['charge amount']) * -1)
      expect(r.intacct_receivable_lines.second.amount).to eq (BigDecimal.new(l2['charge amount']) * -1)
    end

    it "creates an lmd receivable from brokerage file data" do
      @line['line division'] = "11"
      r = @p.create_receivable @export, [@line, @line]

      # Just check the differences in fields between lmd and vfc receivables
      expect(r.customer_number).to eq "VANDE"
      expect(r.company).to eq "lmd"
      expect(r.receivable_type).to eq "LMD Sales Invoice"
      expect(r.invoice_number).to eq @line["invoice number"]
      expect(r.intacct_receivable_lines.first.line_of_business).to eq 'Freight'
      expect(r.intacct_receivable_lines.first.location).to eq @line["line division"]
    end

    it "re-uses an existing lmd receivable for the same broker file with a suffix" do
      # In certain cases, we'll actually have multiple broker files associated w/ the same Freight File.
      # We used to use our own suffixing system, now we just use the same invoice number on the LMD receivable as we use on the brokerage invoice
      different_receivable = IntacctReceivable.create! company: 'lmd', customer_number: "VANDE", invoice_number: "DIFFERENT"
      existing_receivable = IntacctReceivable.create! company: 'lmd', customer_number: "VANDE", invoice_number: @line["invoice number"]

      @line['line division'] = "11"
      r = @p.create_receivable @export, [@line, @line]

      # Verify the invoice number was not changed
      expect(existing_receivable.id).to eq r.id
      expect(r.invoice_number).to eq @line["invoice number"]
    end

    it "creates an lmd receivable from an LMD file" do
      @export.division = "11"
      @line['line division'] = "11"
      r = @p.create_receivable @export, [@line, @line]

      # Just check the differences in fields between lmd and vfc receivables
      expect(r.customer_number).to eq @export.customer_number
      expect(r.company).to eq "lmd"
      expect(r.receivable_type).to eq "LMD Sales Invoice"
      expect(r.invoice_number).to eq @line['invoice number']
      expect(r.intacct_receivable_lines.first.line_of_business).to eq 'Freight'
    end

    it "creates an LMD credit note object" do
      @export.division = "11"
      @line['line division'] = "11"
      l2 = @line.dup
      l2['charge amount'] = "-25"

      r = @p.create_receivable @export, [@line, l2], true
      expect(r.persisted?).to be_true
      expect(r.receivable_type).to eq "LMD Credit Note"

      # Credit memos invert the charge amounts (negative amounts are positive / positive are negative)
      expect(r.intacct_receivable_lines.first.amount).to eq (BigDecimal.new(@line['charge amount']) * -1)
      expect(r.intacct_receivable_lines.second.amount).to eq (BigDecimal.new(l2['charge amount']) * -1)
    end

    it "updates vfc receivables that have not been sent" do
      exists = IntacctReceivable.create! company: 'vfc', invoice_number: @line['invoice number'], customer_number: @export.customer_number, intacct_errors: "errors"
      r = @p.create_receivable @export, [@line, @line], true
      expect(r.id).to eq exists.id
      expect(r.intacct_errors).to be_nil
      # Make sure lines are deleted and recreated
      expect(r.intacct_receivable_lines).to have(2).items
    end

    it "updates lmd receivables from brokerage files that have not been sent" do
      @line['line division'] = "11"
      exists = IntacctReceivable.create! company: 'lmd', customer_number: "VANDE", intacct_errors: "errors", invoice_number: @line['invoice number']
      r = @p.create_receivable @export, [@line, @line]
      expect(r.id).to eq exists.id
      expect(r.intacct_errors).to be_nil
    end

    it "updates lmd receivables from LMD files that have not been sent" do
      @export.division = "11"
      @line['line division'] = "11"
      exists = IntacctReceivable.create! company: 'lmd', invoice_number: @line['invoice number'], customer_number: @export.customer_number, intacct_errors: "errors"
      r = @p.create_receivable @export, [@line, @line]
      expect(r.id).to eq exists.id
      expect(r.intacct_errors).to be_nil
    end

    it "does not create a receivable if a vfc file already exists with an upload date and key" do
      IntacctReceivable.create! company: 'vfc', invoice_number: @line['invoice number'], customer_number: @export.customer_number, intacct_upload_date: Time.zone.now, intacct_key: "Key"
      expect(@p.create_receivable @export, [@line, @line], true).to be_nil
    end

    it "does not create an lmd receivable from a brokerage file if a file already exists with an upload date and key" do
      @line['line division'] = "11"
      IntacctReceivable.create! company: 'lmd', invoice_number: @line['invoice number'], customer_number: "VANDE", intacct_upload_date: Time.zone.now, intacct_key: "Key"
      expect(@p.create_receivable @export, [@line, @line]).to be_nil
    end

    it "does not create an lmd receivable from an LMD file if a file already exists with an upload date and key" do
      @line['line division'] = "11"
      @export.division = "11"
      IntacctReceivable.create! company: 'lmd', invoice_number: @line['invoice number'], customer_number: @export.customer_number, intacct_upload_date: Time.zone.now, intacct_key: "Key"
      expect(@p.create_receivable @export, [@line, @line]).to be_nil
    end

    it "uses customer and vendor xrefs when available" do
      @customer = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @export.customer_number), value: "CUSTOMER", cross_reference_type: DataCrossReference::INTACCT_CUSTOMER_XREF
      @vendor = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @line['vendor']), value: "VENDOR", cross_reference_type: DataCrossReference::INTACCT_VENDOR_XREF

      r = @p.create_receivable @export, [@line]
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

    it "creates a vfc payable" do
      p = @p.create_payable @export, "VENDOR", [@line, @line]

      expect(p.persisted?).to be_true
      expect(p.company).to eq "vfc"
      expect(p.vendor_number).to eq "VENDOR"
      expect(p.vendor_reference).to be_nil
      expect(p.currency).to eq @line["currency"]
      expect(p.bill_number).to eq @line["invoice number"]
      expect(p.bill_date).to eq @export.invoice_date
      expect(p.payable_type).to eq IntacctPayable::PAYABLE_TYPE_BILL

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
      expect(l.customer_number).to eq @export.customer_number
      expect(l.broker_file).to eq @line['broker file number']
      expect(l.check_number).to eq @line["check number"]
      expect(l.bank_number).to eq @bank.value
      expect(l.check_date).to eq Date.strptime @line["check date"], "%Y%m%d"
    end

    it "creates a vfc payable to lmd division" do
      p = @p.create_payable @export, "LMD", [@line]

      expect(p.persisted?).to be_true
      expect(p.company).to eq "vfc"
      expect(p.vendor_number).to eq "LMD"
      expect(p.vendor_reference).to eq @line["freight file number"]
      expect(p.currency).to eq @line["currency"]
      expect(p.bill_number).to eq @line["invoice number"]
      expect(p.bill_date).to eq @export.invoice_date

      
      l = p.intacct_payable_lines.first
      expect(l.gl_account).to eq "6085"

      # Make sure the location is set to the header division for payables to lmd
      expect(l.location).to eq @export.division
    end

    it "creates an LMD payable for division 11" do
      @export.division = "11"

      p = @p.create_payable @export, "LMD VENDOR", [@line]
      expect(p.persisted?).to be_true
      expect(p.company).to eq "lmd"
      expect(p.vendor_number).to eq "LMD VENDOR"
      expect(p.vendor_reference).to be_nil
      expect(p.currency).to eq @line["currency"]
      expect(p.bill_number).to eq @line["invoice number"]
      expect(p.bill_date).to eq @export.invoice_date

      l = p.intacct_payable_lines.first
      expect(l.charge_code).to eq @line["charge code"]
      expect(l.gl_account).to eq @gl_account.value
      expect(l.amount).to eq BigDecimal.new(@line["charge amount"])
      expect(l.charge_description).to eq "#{@line["charge description"]} - #{@line["vendor reference"]}"
      expect(l.location).to eq @line["line division"]
      expect(l.line_of_business).to eq "Freight"
      expect(l.freight_file).to eq @line["freight file number"]
      expect(l.customer_number).to eq @export.customer_number
      expect(l.broker_file).to be_nil
    end

    it "creates an LMD payable for division 12" do
      @export.division = "12"

      p = @p.create_payable @export, "LMD VENDOR", [@line]
      expect(p.persisted?).to be_true
      expect(p.company).to eq "lmd"
    end

    it "updates an existing payable that has not been sent" do
      exists = IntacctPayable.create! company: 'vfc', vendor_number: "VENDOR", bill_number: @line["invoice number"], payable_type: IntacctPayable::PAYABLE_TYPE_BILL, intacct_errors: "Error"

      p = @p.create_payable @export, "VENDOR", [@line]
      expect(exists.id).to eq p.id
      expect(p.intacct_errors).to be_nil
      # Make sure lines are deleted and recreated
      expect(p.intacct_payable_lines).to have(1).item
    end

    it "skips payables that have already been sent" do
      IntacctPayable.create! company: 'vfc', vendor_number: "VENDOR", bill_number: @line["invoice number"], payable_type: IntacctPayable::PAYABLE_TYPE_BILL, intacct_upload_date: Time.zone.now, intacct_key: "KEY"
      expect(@p.create_payable @export, "VENDOR", [@line]).to be_nil
    end

    it "finds alliance exports and creates payables when alliance returns blank string for suffix" do
      @export.update_attributes! suffix: nil
      @line['suffix'] = "         "
      p = @p.create_payable @export, "VENDOR", [@line]
      expect(p).to be_persisted
    end

    it "uses customer and vendor xrefs when available" do
      @customer = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @export.customer_number), value: "CUSTOMER", cross_reference_type: DataCrossReference::INTACCT_CUSTOMER_XREF
      @vendor = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @line['vendor']), value: "VENDOR", cross_reference_type: DataCrossReference::INTACCT_VENDOR_XREF

      p = @p.create_payable @export, @line['vendor'], [@line]
      expect(p.vendor_number).to eq @vendor.value
      expect(p.intacct_payable_lines.first.customer_number).to eq @customer.value
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


      broker_receivables, lmd_receivables = @p.extract_receivable_lines @export, [@line, non_print, lmd_line1, lmd_line2]
      expect(broker_receivables).to have(3).items
      expect(broker_receivables.first).to eq @line
      expect(broker_receivables.second).to eq lmd_line1
      expect(broker_receivables.third).to eq lmd_line2

      expect(lmd_receivables).to have(2).items
      expect(lmd_receivables.first).to eq lmd_line1
      expect(lmd_receivables.second).to eq lmd_line2
    end

    it "extracts receivables and payables from an lmd invoice file for Ocean Freight Division" do
      @export.division = "11"

      broker_receivables, lmd_receivables = @p.extract_receivable_lines @export, [@line]
      expect(broker_receivables).to have(0).items
      expect(lmd_receivables).to have(1).items
    end

    it "extracts receivables and payables from an lmd invoice file for Air Freight Division" do
      @export.division = "12"

      broker_receivables, lmd_receivables = @p.extract_receivable_lines @export, [@line]
      expect(broker_receivables).to have(0).items
      expect(lmd_receivables).to have(1).items
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

      broker_payable, lmd_payable = @p.extract_payable_lines @export, [@line, line2, non_payable, lmd_line, lmd_line2]
      expect(broker_payable.keys).to have(3).items
      expect(broker_payable[@line["vendor"]]).to have(1).item
      expect(broker_payable[line2["vendor"]]).to have(1).item
      expect(broker_payable["LMD"]).to have(2).items

      expect(lmd_payable.keys).to have(0).items
    end

    it "pulls out all lmd payable lines from a result set for Ocean Freight Invoices" do
      @export.division = "11"
      @line['payable'] = "Y"
      line2 = @line.dup
      line2['vendor'] = "VENDOR2"
      non_payable = line2.dup
      non_payable['payable'] = "N"

      broker_payable, lmd_payable = @p.extract_payable_lines @export, [@line, line2, non_payable]
      expect(broker_payable.keys).to have(0).items
      expect(lmd_payable.keys).to have(2).items

      expect(lmd_payable[@line["vendor"]]).to have(1).item
      expect(lmd_payable[line2["vendor"]]).to have(1).item
    end

    it "pulls out all lmd payable lines from a result set for Air Freight Invoices" do
      @export.division = "12"
      @line['payable'] = "Y"
      non_payable = @line.dup
      non_payable['payable'] = "N"

      broker_payable, lmd_payable = @p.extract_payable_lines @export, [@line, non_payable]
      expect(broker_payable.keys).to have(0).items
      expect(lmd_payable.keys).to have(1).items

      expect(lmd_payable[@line["vendor"]]).to have(1).item
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
      expect(receivables.find {|r| r.company == "lmd"}.invoice_number).to eq @line["invoice number"]
      found = receivables.find_all {|r| r.company == "vfc"}
      expect(found.size).to eq 1
      expect(found[0].intacct_errors).to be_nil

      payables = @export.intacct_payables
      expect(payables).to have(2).items

      expect(payables.find_all {|p| p.vendor_number == "LMD"}).to have(1).item
      found = payables.find_all {|p| p.vendor_number == line2['vendor']}
      expect(found.size).to eq 1
      expect(found[0].intacct_errors).to be_nil
    end

    it "parses an lmd file result set into receivables and payables and saves them all" do
      @export.division = "11"
      @export.save!
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

    it "handles payable lines with incomplete check information" do
      # Somehow lines that are not checks have check dates in them (user error likely) and were causing issues 
      # creating payables (.ie they're identified as seperate payables).  Make sure this is resolved.
      @line["payable"] = "Y"
      @line["freight file number"] = ""
      @line['check date'] = '20140701'
      @line['check number'] = '0'
      @line['bank number'] = '0'

      line2 = @line.dup
      line2['check date'] = '0'

      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:delay).and_return OpenChain::CustomHandler::Intacct::IntacctClient
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Broker File", @line["broker file number"], @line["broker file number"])

      @p.parse [@line, line2]

      @export.reload

      payables = @export.intacct_payables
      expect(payables.size).to eq 1
      expect(payables.first.intacct_payable_lines.size).to eq 2
    end

    it "finds alliance exports and creates receivables when alliance returns blank string for suffix" do
      @export.update_attributes! suffix: nil
      @line['suffix'] = "         "
      @p.parse [@line]

      @export.reload
      expect(@export.intacct_receivables.size).to eq 1
    end

    it "it detects invalid AR amounts and marks valid payables with errors if receivables have errors" do
      @line["payable"] = "Y"
      @export.update_attributes! ar_total: '0'

      @p.parse [@line]

      @export.reload

      expect(@export.intacct_receivables.size).to eq 1
      expect(@export.intacct_receivables[0].intacct_errors).to eq "Expected an AR Total of $0.00.  Received from Alliance: $12.50."

      expect(@export.intacct_payables.size).to eq 1
      expect(@export.intacct_payables[0].intacct_errors).to eq "Errors were found in corresponding receivables for this file.  Please address those errors before clearing this payable."
    end

    it "it detects invalid AR amounts on credits and marks valid payables with errors if receivables have errors" do
      @line["payable"] = "Y"
      @export.update_attributes! ar_total: '-6.00', ap_total: '-10.00'
      @line["charge amount"] = "-10.00"

      @p.parse [@line]

      @export.reload

      expect(@export.intacct_receivables.size).to eq 1
      expect(@export.intacct_receivables[0].intacct_errors).to eq "Expected an AR Total of -$6.00.  Received from Alliance: -$10.00."

      expect(@export.intacct_payables.size).to eq 1
      expect(@export.intacct_payables[0].intacct_errors).to eq "Errors were found in corresponding receivables for this file.  Please address those errors before clearing this payable."
    end

    it "detects invalid AP amounts and marks valid receivables with errors if payables have errors" do
      @line["payable"] = "Y"
      @export.update_attributes! ap_total: '0'

      @p.parse [@line]

      @export.reload

      expect(@export.intacct_receivables.size).to eq 1
      expect(@export.intacct_receivables[0].intacct_errors).to eq "Errors were found in corresponding payables for this file.  Please address those errors before clearing this receivable."

      expect(@export.intacct_payables.size).to eq 1
      expect(@export.intacct_payables[0].intacct_errors).to eq "Expected an AP Total of $0.00.  Received from Alliance: $12.50."
    end
  end

  describe "parse_check_query_results" do

    before :each do
      @export = IntacctAllianceExport.create! file_number: '12345', check_number: '98765', export_type: IntacctAllianceExport::EXPORT_TYPE_CHECK, ap_total: BigDecimal.new("100")
      @check = IntacctCheck.create! file_number: '12345', check_number: '98765', intacct_alliance_export_id: @export.id, intacct_errors: "Error", customer_number: "CUST", vendor_number: "VEND", amount: BigDecimal.new("100")
      @line = {'file number' => '12345', 'check number'=>'98765', 'division'=>'1', 'currency'=>"CAD", 'freight file' => '2131789', 'check amount' => '100'}
    end

    it "updates vfc check info" do
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:delay).exactly(2).times.and_return OpenChain::CustomHandler::Intacct::IntacctClient
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Broker File", @line["file number"], @line["file number"])
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Freight File", @line["freight file"], @line["freight file"])

      customer = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @check.customer_number), value: "CUSTOMER", cross_reference_type: DataCrossReference::INTACCT_CUSTOMER_XREF
      vendor = DataCrossReference.create! key: DataCrossReference.make_compound_key("Alliance", @check.vendor_number), value: "VENDOR", cross_reference_type: DataCrossReference::INTACCT_VENDOR_XREF


      @p.parse_check_result [@line]

      @export.reload

      expect(@export.data_received_date).to_not be_nil
      check = @export.intacct_checks.first

      expect(check.intacct_errors).to be_nil
      expect(check.company).to eq "vfc"
      expect(check.line_of_business).to eq "Brokerage"
      expect(check.location).to eq @line['division']
      expect(check.currency).to eq @line['currency']
      expect(check.freight_file).to eq @line['freight file']
      expect(check.broker_file).to eq @line['file number']
      expect(check.customer_number).to eq customer.value
      expect(check.vendor_number).to eq vendor.value

      expect(@export.division).to eq check.location
    end

    it "updates updates customer and vendor numbers using xref values" do
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:delay).exactly(2).times.and_return OpenChain::CustomHandler::Intacct::IntacctClient
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Broker File", @line["file number"], @line["file number"])
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Freight File", @line["freight file"], @line["freight file"])

      @p.parse_check_result [@line]

      @export.reload

      expect(@export.data_received_date).to_not be_nil
      check = @export.intacct_checks.first

      expect(check.intacct_errors).to be_nil
      expect(check.company).to eq "vfc"
      expect(check.line_of_business).to eq "Brokerage"
      expect(check.location).to eq @line['division']
      expect(check.currency).to eq @line['currency']
      expect(check.freight_file).to eq @line['freight file']
      expect(check.broker_file).to eq @line['file number']

      expect(@export.division).to eq check.location
    end

    it 'updates lmd check info' do
      @line['division'] = '11'

      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:delay).once.and_return OpenChain::CustomHandler::Intacct::IntacctClient
      OpenChain::CustomHandler::Intacct::IntacctClient.should_receive(:async_send_dimension).with("Freight File", @line["freight file"], @line["freight file"])

      @p.parse_check_result [@line]

      @export.reload

      expect(@export.data_received_date).to_not be_nil
      check = @export.intacct_checks.first

      expect(check.intacct_errors).to be_nil
      expect(check.company).to eq "lmd"
      expect(check.line_of_business).to eq "Freight"
      expect(check.location).to eq @line['division']
      expect(check.currency).to eq @line['currency']
      expect(check.freight_file).to eq @line['freight file']
      expect(check.broker_file).to be_nil
    end
  end
end