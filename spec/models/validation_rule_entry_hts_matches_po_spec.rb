require 'spec_helper'

describe ValidationRuleEntryHtsMatchesPo do

  describe "run_child_validation" do
    before :each do
      # Create the rule here so we also force creation of the custom def done via its constructor
      @cust_def = CustomDefinition.create!(label: "Part Number", module_type: 'Product', data_type: :string)

      importer = Factory(:importer)

      tariff_line = Factory(:commercial_invoice_tariff, hts_code: "1234567890",
        commercial_invoice_line: Factory(:commercial_invoice_line, po_number: "PO", part_number: "1234", country_origin_code: "ZZ")
      )
      @invoice_line = tariff_line.commercial_invoice_line
      @invoice_line.entry.update_attributes! importer_id: importer.id

      tariff_record = Factory(:tariff_record, hts_1: "1234567890", 
        classification: Factory(:classification, country: Factory(:country, iso_code: "US"),
          product: Factory(:product, importer_id: importer.id)
        )
      )
      @product = tariff_record.classification.product
      @cust_def = CustomDefinition.where(label: "Part Number").first
      @product.update_custom_value! @cust_def, @invoice_line.part_number


      @order_line = Factory(:order_line, country_of_origin: "ZZ", hts: "1234567890", product: @product,
        order: Factory(:order, customer_order_number: @invoice_line.po_number, importer: importer)
      )
      @order = @order_line.order
      @rule = described_class.new
    end

    it "matches invoice line to PO and Product lines" do
      expect(@rule.run_child_validation @invoice_line).to be_nil
    end

    it "fails if Product HTS doesn't match" do
      @product.classifications.first.tariff_records.first.update_attributes! hts_1: "9876543210"

      expect(@rule.run_child_validation @invoice_line).to eq "Invoice Line for PO #{@invoice_line.po_number} / Part #{@invoice_line.part_number} matches to an Order line, but not to any Product associated with the Order."
    end

    it "fails if Product Country doesn't match" do
      @product.classifications.first.update_attributes! country: Factory(:country)

      expect(@rule.run_child_validation @invoice_line).to eq "Invoice Line for PO #{@invoice_line.po_number} / Part #{@invoice_line.part_number} matches to an Order line, but not to any Product associated with the Order."
    end

    it "skips Product validation if rule attributes tell it to" do
      @rule.update_attributes! rule_attributes_json: '{"validate_product":false}'
      @product.classifications.first.tariff_records.first.update_attributes! hts_1: "9876543210"
      expect(@rule.run_child_validation @invoice_line).to be_nil
    end

    it "uses a different classification country to validate product data against" do
      @rule.update_attributes! rule_attributes_json: '{"classification_country":"CA"}'
      @product.classifications.first.update_attributes! country: Factory(:country, iso_code: "CA")
      expect(@rule.run_child_validation @invoice_line).to be_nil
    end

    it "validates against PO HTS code" do
      @order_line.update_attributes! hts: '9876543210'

      expect(@rule.run_child_validation @invoice_line).to eq "Invoice Line for PO #{@invoice_line.po_number} / Part #{@invoice_line.part_number} does not match any Order line's Tariff and Country of Origin."
    end

    it "validates against PO country of origin" do
      @order_line.update_attributes! country_of_origin: "YY"

      expect(@rule.run_child_validation @invoice_line).to eq "Invoice Line for PO #{@invoice_line.po_number} / Part #{@invoice_line.part_number} does not match any Order line's Tariff and Country of Origin."
    end

    it "validates PO Line exists" do
      @product.update_custom_value! @cust_def, "987"

      expect(@rule.run_child_validation @invoice_line).to eq "No Order Line found for PO # #{@invoice_line.po_number} and Part # #{@invoice_line.part_number}."
    end

    it "validates PO exists" do
      @order.update_attributes! customer_order_number: "OP"

      expect(@rule.run_child_validation @invoice_line).to eq "No Order found for PO # #{@invoice_line.po_number}."
    end
  end
end