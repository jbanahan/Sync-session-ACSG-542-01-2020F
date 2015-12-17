require 'spec_helper'

describe ValidationRuleAscenaInvoiceAudit do
  before :each do
    @ent = Factory(:entry, commercial_invoice_numbers: "123456789\n 987654321")
    @rule = described_class.new(rule_attributes_json: {hts_list: ['123456789', '987654321'], style_list: ['1111', '2222']}.to_json)
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.stub(:gather_unrolled)
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.stub(:gather_entry)
  end

  it "passes if all six tests succeed" do
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_value_per_hts_coo_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_qty_per_hts_coo_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_value_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_qty_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:hts_set_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:style_set_match).with(['1111', '2222'].to_set).and_return ""

    expect(@rule.run_validation @ent).to be_nil
  end
  
  it "fails if any of the six tests fails" do
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_value_per_hts_coo_diff).and_return "ERROR: total value per hts/coo"
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_qty_per_hts_coo_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_value_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_qty_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:hts_set_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:style_set_match).with(['1111', '2222'].to_set).and_return ""

    expect(@rule.run_validation @ent).to eq "ERROR: total value per hts/coo"
  end

  it "produces multiple error messages if there are multiple failing tests" do
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_value_per_hts_coo_diff).and_return "ERROR: total value per hts/coo"
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_qty_per_hts_coo_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_value_diff).and_return "ERROR: total value"
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_qty_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:hts_set_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:style_set_match).with(['1111', '2222'].to_set).and_return "ERROR: style set"

    expect(@rule.run_validation @ent).to eq "ERROR: total value per hts/coo\nERROR: total value\nERROR: style set"
  end

  it "abridges the error list if it's too long" do
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_value_per_hts_coo_diff).and_return "z" * (described_class::MAX_LENGTH + 1)
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_qty_per_hts_coo_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_value_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:total_qty_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:hts_set_diff).and_return ""
    OpenChain::AscenaInvoiceValidatorHelper.any_instance.should_receive(:style_set_match).with(['1111', '2222'].to_set).and_return ""
    result = @rule.run_validation @ent
    
    expect(result.length).to eq described_class::MAX_LENGTH
    expect(result[0..23]).to eq "This message is too long"
    expect(result[-3..-1]).to eq "..."
  end

end