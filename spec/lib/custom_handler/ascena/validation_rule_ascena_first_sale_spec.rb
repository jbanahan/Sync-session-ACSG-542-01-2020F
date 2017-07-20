describe OpenChain::CustomHandler::Ascena::ValidationRuleAscenaFirstSale do

  describe "run_validation" do
    let (:entry) {
      e = Factory(:entry, entry_filed_date: Date.new(2017,4,21))
      i = e.commercial_invoices.create! invoice_number: "INV"
      l = i.commercial_invoice_lines.create! line_number: 1, value_appraisal_method: "F", mid: "MID", contract_amount: 10, po_number: '12345'
      l.commercial_invoice_tariffs.create! entered_value: 5
      l = i.commercial_invoice_lines.create! line_number: 2, value_appraisal_method: "F", mid: "MID2", contract_amount: 10, po_number: '54321'
      l.commercial_invoice_tariffs.create! entered_value: 5
      e
    }

    before do
      v1 = Factory(:company, system_code: "ACME")
      v2 = Factory(:company, system_code: "KONVENIENTZ")
      Factory(:order, vendor: v1, order_number: "ASCENA-12345")
      Factory(:order, vendor: v2, order_number: "ASCENA-54321")
    end

    let! (:mids) {
      DataCrossReference.add_xref! DataCrossReference::ASCE_MID, 'MID-ACME', '2017-03-15'
      DataCrossReference.add_xref! DataCrossReference::ASCE_MID, 'MID2-KONVENIENTZ', '2017-04-20'
    }

    it "validates presence of first sale information on invoice lines that are first sale MIDs" do
      expect(subject.run_validation entry).to be_nil
    end

    it "errors if value appraisal method is wrong or contract amount is missing" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! value_appraisal_method: "C"
      entry.commercial_invoices.first.commercial_invoice_lines.second.update_attributes! contract_amount: nil

      expect(subject.run_validation entry).to eq "Invoice # INV / Line # 1 must have Value Appraisal Method and Contract Amount set.\nInvoice # INV / Line # 2 must have Value Appraisal Method and Contract Amount set."
    end

    it "does not error if MID is not in xref" do      
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! value_appraisal_method: "C"
      entry.commercial_invoices.first.commercial_invoice_lines.second.update_attributes! contract_amount: nil

      DataCrossReference.destroy_all

      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if entry-filed date is before the FS Start Date" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! value_appraisal_method: "C"
      entry.commercial_invoices.first.commercial_invoice_lines.second.update_attributes! contract_amount: nil

      entry.update_attributes(entry_filed_date: Date.new(2017,3,10))

      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if invoice number indicates Non-First sale" do
      entry.commercial_invoices.first.update_attributes! invoice_number: "INVNFS"

      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if invoice number indicates Minimum" do
      entry.commercial_invoices.first.update_attributes! invoice_number: "INVMIN"

      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if MOT = 40 and line has non-dutable charges" do
      entry.update_attributes! transport_mode_code: "40"
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! value_appraisal_method: "C", non_dutiable_amount: 20

      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if the entry filed date is nil" do
      entry.update_attributes! entry_filed_date: nil
      expect(subject.run_validation entry).to be_nil
    end

    it "errors if first sale amount is less than the entered value" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! contract_amount: 4
      expect(subject.run_validation entry).to eq "Invoice # INV / Line # 1 must have a First Sale Contract Amount greater than the Entered Value."
    end
  end
  
end