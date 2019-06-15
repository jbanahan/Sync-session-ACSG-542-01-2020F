describe ValidationRuleEntryInvoiceLineMatchesPo do

  describe "run_child_validation" do
    before :each do
      @line = Factory(:commercial_invoice_line, po_number: "PONUMBER")
      @line.entry.importer = Factory(:company, importer: true)
    end

    it "notfies if no matching PO is found" do
      expect(subject.run_child_validation @line).to eq "No Order found for PO # #{@line.po_number}."
    end

    it "does not notify if PO is found" do
      po = Factory(:order, importer: @line.entry.importer, customer_order_number: @line.po_number)

      expect(subject.run_child_validation @line).to be_nil
    end

    it "does not notify if PO is found when importer comes from rule attributes" do
      importer = Factory(:company, importer: true)
      expect(subject).to receive(:rule_attributes).and_return({"importer_id"=>importer.id}).twice
      po = Factory(:order, importer: importer, customer_order_number: @line.po_number)

      expect(subject.run_child_validation @line).to be_nil
    end

    it "involves caching in the PO look-up" do
      po = instance_double(Order)
      # This should be called only once despite validation being run twice.
      expect(Order).to receive(:where).with(:importer_id=>@line.entry.importer_id, :customer_order_number=>"PONUMBER").and_return([po]).once
      # This is called exactly once too to verify keys are being involved properly.  Different PO number.
      expect(Order).to receive(:where).with(:importer_id=>@line.entry.importer_id, :customer_order_number=>"PONUMBER2").and_return([po]).once

      line2 = Factory(:commercial_invoice_line, po_number: "PONUMBER2")
      line2.entry.importer = @line.entry.importer

      expect(subject.run_child_validation @line).to be_nil
      expect(subject.run_child_validation @line).to be_nil
      expect(subject.run_child_validation line2).to be_nil
    end
  end

end
