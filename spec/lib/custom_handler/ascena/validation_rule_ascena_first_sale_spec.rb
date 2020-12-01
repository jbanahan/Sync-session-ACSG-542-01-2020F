describe OpenChain::CustomHandler::Ascena::ValidationRuleAscenaFirstSale do

  describe "run_validation" do
    let (:entry) {
      e = FactoryBot(:entry, customer_number: "ASCE", entry_filed_date: Date.new(2017, 4, 21))
      i = e.commercial_invoices.create! invoice_number: "INV"
      l = i.commercial_invoice_lines.create! line_number: 1, value_appraisal_method: "F", mid: "MID", contract_amount: 10, po_number: '12345', product_line: 'JST'
      l.commercial_invoice_tariffs.create! entered_value: 5
      l = i.commercial_invoice_lines.create! line_number: 2, value_appraisal_method: "F", mid: "MID2", contract_amount: 10, po_number: '54321', product_line: 'JST'
      l.commercial_invoice_tariffs.create! entered_value: 5
      e
    }

    before do
      FactoryBot(:order, vendor: FactoryBot(:company, system_code: "ACME"), factory: FactoryBot(:company, mid: "MID"), order_number: "ASCENA-JST-12345")
      FactoryBot(:order, vendor: FactoryBot(:company, system_code: "KONVENIENTZ"), factory: FactoryBot(:company, mid: "MID2"), order_number: "ASCENA-JST-54321")
    end

    let! (:mids) {
      DataCrossReference.add_xref! DataCrossReference::ASCE_MID, 'MID-ACME', '2017-03-15'
      DataCrossReference.add_xref! DataCrossReference::ASCE_MID, 'MID2-KONVENIENTZ', '2017-04-20'
    }

    it "throws exception for any entries with customer numbers other than 'ASCE', 'MAUR'" do
      entry.update! customer_number: "ACME"
      expect { subject.run_validation entry }.to raise_error "Validation can only be run with customers 'ASCE' and 'MAUR'. Found: ACME"
    end

    # These two context blocks are meant to show with two representative tests that the suite can be run
    # for either Ascena or Maurices (though the rest uses Ascena exclusively)

    context "Ascena" do
      it "validates presence of first sale information on invoice lines that are first sale MIDs" do
        expect(subject.run_validation entry).to be_nil
      end

      it "errors if value appraisal method is wrong or contract amount is missing" do
        entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! value_appraisal_method: "C"
        entry.commercial_invoices.first.commercial_invoice_lines.second.update_attributes! contract_amount: nil
        expect(subject.run_validation entry).to eq "Invoice # INV / Line # 1 must have Value Appraisal Method and Contract Amount set.\nInvoice # INV / Line # 2 must have Value Appraisal Method and Contract Amount set."
      end
    end

    context "Maurices" do
      before do
        Order.all.each do |o|
          old = o.order_number.split("-").last
          o.update! order_number: "ASCENA-MAU-#{old}"
        end

        entry.update! customer_number: "MAUR"
      end

      it "validates presence of first sale information on invoice lines that are first sale MIDs" do
        expect(subject.run_validation entry).to be_nil
      end

      it "errors if value appraisal method is wrong or contract amount is missing" do
        entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! value_appraisal_method: "C"
        entry.commercial_invoices.first.commercial_invoice_lines.second.update_attributes! contract_amount: nil
        expect(subject.run_validation entry).to eq "Invoice # INV / Line # 1 must have Value Appraisal Method and Contract Amount set.\nInvoice # INV / Line # 2 must have Value Appraisal Method and Contract Amount set."
      end
    end

    it "does not error if entry-filed date is before the FS Start Date as long as Vendor-MID isn't in xref" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! value_appraisal_method: "C"
      entry.commercial_invoices.first.commercial_invoice_lines.second.update_attributes! contract_amount: nil, mid: "FOO"
      Order.where(order_number: "ASCENA-JST-54321").first.factory.update_attributes! mid: "FOO"

      entry.update_attributes(entry_filed_date: Date.new(2017, 3, 10))

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

    it "errors for first-sale invoice line if associated vendor-MID ISN'T in xref" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! mid: "FOO"
      Order.where(order_number: "ASCENA-JST-12345").first.factory.update_attributes! mid: "FOO"
      expect(subject.run_validation entry).to eq "Invoice # INV / Line # 1 must have a Vendor-MID combination on the approved first-sale list."
    end

    it "errors for non-first-sale invoice line if associated vendor-MID IS in xref" do
      entry.update_attributes! entry_filed_date: Date.new(2017, 3, 14)
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! contract_amount: 0
      expect(subject.run_validation entry).to eq "Invoice # INV / Line # 1 must not have a Vendor-MID combination on the approved first-sale list."
    end

    it "errors if line's po number is invalid" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! po_number: "FOO"
      expect(subject.run_validation entry).to eq "Invoice # INV / Line # 1 has an invalid PO number."
    end

    it "errors if line's MID doesn't match order's" do
      Order.where(order_number: "ASCENA-JST-12345").first.factory.update_attributes! mid: "FOO"
      expect(subject.run_validation entry).to eq  "Invoice # INV / Line # 1 must have an MID that matches to the PO. Invoice MID is 'MID' / PO MID is 'FOO'"
    end

    it "doesn't error if order's MID is missing" do
      Order.where(order_number: "ASCENA-JST-12345").first.factory.update_attributes! mid: nil
      expect(subject.run_validation entry).to be_nil
    end

  end

end
