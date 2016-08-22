require 'spec_helper'

describe ValidationRuleEntryInvoiceCooMatchesSpi do
  before :each do
    @rule = described_class.new(rule_attributes_json:{"BD" => "8", "IL" => "13"}.to_json)
    
    @e = Factory(:entry)
    ci = Factory(:commercial_invoice, entry: @e, invoice_number: "12345")
    @cil_1 = Factory(:commercial_invoice_line, commercial_invoice: ci, part_number: "111", country_origin_code: "BD")
    @cil_2 = Factory(:commercial_invoice_line, commercial_invoice: ci, part_number: "222", country_origin_code: "IL")
    Factory(:commercial_invoice_tariff, commercial_invoice_line: @cil_1, spi_primary: "8")
    Factory(:commercial_invoice_tariff, commercial_invoice_line: @cil_2, spi_primary: "13")
  end 

  describe "run_validation" do
    it "passes if every invoice line has a country-origin code that matches the primary spi on its tariffs" do
      expect(@rule.run_validation(@e)).to be_nil
    end

    it "passes if an invoice line's country-origin code doesn't have an assigned primary spi" do
      cil_3 = Factory(:commercial_invoice_line, entry: @e, country_origin_code: "US")
      Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_3, spi_primary: "123")
      expect(@rule.run_validation(@e)).to be_nil
    end

    it "fails if any invoice line has a country-origin code that doesn't match the primary spi on its tariffs" do
      Factory(:commercial_invoice_tariff, commercial_invoice_line: @cil_1, spi_primary: "9")
      Factory(:commercial_invoice_tariff, commercial_invoice_line: @cil_2, spi_primary: "14")
      expect(@rule.run_validation(@e)).to eq "The following invoices have a country-of-origin code that doesn't match its primary SPI:\n12345 part 111\n12345 part 222"
    end

  end
end