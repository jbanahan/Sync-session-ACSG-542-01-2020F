require 'spec_helper'

describe ValidationRuleEntryDutyFree do
  before :each do
    @rule = ValidationRuleEntryDutyFree.new(rule_attributes_json: {spi_primary: '8'}.to_json)
    @ci_line = Factory(:commercial_invoice_line)
    @ci_tariff_1 = Factory(:commercial_invoice_tariff, commercial_invoice_line: @ci_line, spi_primary: 8)
    @ci_tariff_2 = Factory(:commercial_invoice_tariff, commercial_invoice_line: @ci_line, spi_primary: 8)
  end

  it "passes if tariffs have the specifed SPI and invoice line is duty-free" do
    allow(@ci_line).to receive(:total_duty).and_return 0
    expect(@rule.run_validation(@ci_line.entry)).to be_nil
  end

  it "passes if tariffs have a different SPI and invoice line is not duty-free" do
    allow(@ci_line).to receive(:total_duty).and_return 5
    @ci_tariff_1.update_attributes(spi_primary: 5)
    @ci_tariff_2.update_attributes(spi_primary: 5)
    expect(@rule.run_validation(@ci_line.entry)).to be_nil
  end

  it "fails if tariffs have the specified SPI but invoice line is not duty-free" do
    @ci_tariff_1.update_attributes(duty_amount: 10)
    expect(@rule.run_validation(@ci_line.entry)).to eq "Invoice line with SPI 8 should be duty free."
  end

end