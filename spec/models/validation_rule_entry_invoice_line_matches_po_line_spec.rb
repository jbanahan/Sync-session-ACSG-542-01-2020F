require 'spec_helper'

describe ValidationRuleEntryInvoiceLineMatchesPoLine do 

  describe "run_child_validation" do

    before :each do 
      @part_no_cd = CustomDefinition.create! label: "Part Number", module_type: "Product", data_type: "string"
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
      product = Factory(:product, importer: @line.entry.importer)
      product.update_custom_value! @part_no_cd, @line.part_number

      po.order_lines.create! product: product

      expect(described_class.new.run_child_validation @line).to be_nil
    end

    it "notifies if extra field does not match" do
      po = Factory(:order, importer: @line.entry.importer, customer_order_number: @line.po_number)
      product = Factory(:product, importer: @line.entry.importer)
      product.update_custom_value! @part_no_cd, @line.part_number

      po.order_lines.create! product: product, quantity: 10
      @line.update_attributes(quantity:11)

      h = {match_fields:[{invoice_line_field:'cil_units',order_line_field:'ordln_ordered_qty',operator:'gt'}]}
      expect(described_class.new(rule_attributes_json:h.to_json).run_child_validation @line).to eq "No matching order for PO # #{@line.po_number} and Part # #{@line.part_number} where #{ModelField.find_by_uid(:ordln_ordered_qty).label(false)} Greater Than #{ModelField.find_by_uid(:cil_units).label(false)} (11.0)"
    end

    it 'does not notify if field matches' do
      po = Factory(:order, importer: @line.entry.importer, customer_order_number: @line.po_number)
      product = Factory(:product, importer: @line.entry.importer)
      product.update_custom_value! @part_no_cd, @line.part_number

      po.order_lines.create! product: product, quantity: 10
      @line.update_attributes(quantity:11)

      h = {match_fields:[{invoice_line_field:'cil_units',order_line_field:'ordln_ordered_qty',operator:'lt'}]}
      expect(described_class.new(rule_attributes_json:h.to_json).run_child_validation @line).to be_nil 
    end
  end
end
