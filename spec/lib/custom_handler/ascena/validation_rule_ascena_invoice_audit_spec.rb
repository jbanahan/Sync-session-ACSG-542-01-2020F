require 'spec_helper'

describe OpenChain::CustomHandler::Ascena::ValidationRuleAscenaInvoiceAudit do
  before :each do
    @ent = Factory(:entry, commercial_invoice_numbers: "123456789\n 987654321")
    @rule = described_class.new(rule_attributes_json: {style_list: ['1111', '2222']}.to_json)
    @helper_class = OpenChain::CustomHandler::Ascena::AscenaInvoiceValidatorHelper
  end

  describe :run_validation do
    it "returns nil if no errors are returned" do
      expect_any_instance_of(@helper_class).to receive(:audit).with(@ent, ['1111', '2222']).and_return ""
      expect(@rule.run_validation @ent).to be_nil
    end

    it "abridges the error list if it's too long" do
      expect_any_instance_of(@helper_class).to receive(:audit).with(@ent, ['1111', '2222']).and_return "z" * (described_class::MAX_LENGTH + 1)
      result = @rule.run_validation @ent

      expect(result.length).to eq described_class::MAX_LENGTH
      expect(result[0..23]).to eq "This message is too long"
      expect(result[-3..-1]).to eq "..."
    end
  end

end