require 'spec_helper'

describe ValidationRuleEntryInvoiceLineMatchesPoLine do 

  describe "run_child_validation" do

    before :each do 
      @line = Factory(:commercial_invoice_line, po_number: "PONUMBER", part_number: "PARTNUMBER")
      @line.entry.importer = Factory(:company, importer: true)
    end

    it "notfies if no PO is found with for the line" do
      expect(described_class.new.run_child_validation @line).to eq "No Order found for PO # #{@line.po_number}."
    end

    it "notifies if PO is found without the line" do
      po = Factory(:order, importer: @line.entry.importer, customer_order_number: @line.po_number)
      expect(described_class.new.run_child_validation @line).to eq "No Order Line found for PO # #{@line.po_number} and Part # #{@line.part_number}."
    end

    it "does not notify if PO and line are found" do
      po = Factory(:order, importer: @line.entry.importer, customer_order_number: @line.po_number)
      po.order_lines.create! item_identifier: @line.part_number

      expect(described_class.new.run_child_validation @line).to be_nil
    end
  end
end