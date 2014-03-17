require 'spec_helper'

describe BusinessValidationRule do
  describe :should_skip?
    it "should base should_skip? on search_criterions" do
      pass_ent = Entry.new(entry_number:'9')
      fail_ent = Entry.new(entry_number:'7')
      bvr = BusinessValidationRule.new
      bvr.search_criterions.build(model_field_uid:'ent_entry_num',operator:'eq',value:'9')
      expect(bvr.should_skip?(pass_ent)).to be_false
      expect(bvr.should_skip?(fail_ent)).to be_true
    end
    it "should raise exception if search_criterion's model field CoreModule doesn't equal object's CoreModule" do
      bvr = BusinessValidationRule.new
      bvr.search_criterions.build(model_field_uid:'ent_entry_num',operator:'eq',value:'9')
      ci = CommercialInvoiceLine.new
      expect {bvr.should_skip? ci}.to raise_error /Invalid object expected Entry got CommercialInvoiceLine/
    end
end
