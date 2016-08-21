require 'spec_helper'

describe BusinessValidationRule do
  describe :enabled? do
    it "should not return !enabled in subclasses_array" do
      expect(described_class.subclasses_array.find {|a| a[1]=='PoloValidationRuleEntryInvoiceLineMatchesPoLine'}).to be_nil
    end
    it "should return when no enabled lambda in subclasses_array" do
      a = described_class.subclasses_array
      expect(a.find {|a| a[1]=='ValidationRuleManual'}).to_not be_nil
    end
  end
  describe :should_skip? do
    it "should base should_skip? on search_criterions" do
      pass_ent = Entry.new(entry_number:'9')
      fail_ent = Entry.new(entry_number:'7')
      bvr = BusinessValidationRule.new
      bvr.search_criterions.build(model_field_uid:'ent_entry_num',operator:'eq',value:'9')
      expect(bvr.should_skip?(pass_ent)).to be_falsey
      expect(bvr.should_skip?(fail_ent)).to be_truthy
    end
    it "should raise exception if search_criterion's model field CoreModule doesn't equal object's CoreModule" do
      bvr = BusinessValidationRule.new
      bvr.search_criterions.build(model_field_uid:'ent_entry_num',operator:'eq',value:'9')
      ci = CommercialInvoiceLine.new
      expect {bvr.should_skip? ci}.to raise_error /Invalid object expected Entry got CommercialInvoiceLine/
    end
  describe :async_destroy do
    it "destroys record" do
      rule = Factory(:business_validation_rule)
      described_class.async_destroy rule.id
      expect(described_class.count).to eq 0
    end
  end

  end
end
