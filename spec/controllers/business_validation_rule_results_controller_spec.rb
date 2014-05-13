require 'spec_helper'

describe BusinessValidationRuleResultsController do
  describe :update do
    before :each do 
      @u = Factory(:master_user)
      @ent = Factory(:entry)
      @rr = Factory(:business_validation_rule_result,state:'Fail')
      bvr = @rr.business_validation_result
      bvr.state='Fail'
      bvr.validatable = @ent
      bvr.save!

      sign_in_as @u
    end
    it "should return json if requested" do
      @rr.business_validation_rule.update_attributes(name:'myname')
      put :update, id: @rr.id, business_validation_rule_result:{note:'abc', state:'Pass'}, format: :json
      @rr.reload
      h = JSON.parse(response.body)['save_response']
      expect(h['result_state']).to eq 'Pass'
      rr = h['rule_result']
      expect(rr['id']).to eq @rr.id
      expect(rr['state']).to eq 'Pass'
      expect(rr['rule']['name']).to eq 'myname'
      expect(rr['note']).to eq 'abc'
      expect(rr['overridden_by']['full_name']).to eq @u.full_name
      expect(Time.parse(rr['overridden_at'])).to eq @rr.overridden_at
    end
    it "should not allow update if user cannot update business_validation_rule_result" do
      BusinessValidationRuleResult.any_instance.should_receive(:can_edit?).with(@u).and_return(false)
      put :update, id: @rr.id, business_validation_rule_result:{note:'abc', state:'Pass'} 
      expect(response).to be_redirect
      @rr.reload
      expect(@rr.note).to be_nil
      expect(@rr.state).to eq 'Fail'
    end
    it "should allow update for admins" do
      #change this rule once final decision on security is made
      put :update, id: @rr.id, business_validation_rule_result:{note:'abc', state:'Pass'} 
      expect(response).to redirect_to validation_results_entry_path(@ent)
      @rr.reload
      expect(@rr.note).to eq 'abc'
      expect(@rr.state).to eq 'Pass'
    end
    it "should update state for business validation result" do
      put :update, id: @rr.id, business_validation_rule_result:{note:'abc', state:'Pass'} 
      @rr.reload
      expect(@rr.business_validation_result.state).to eq 'Pass'
    end
    it "should sanitize other fields" do
      @rr.update_attributes(message:'xyz')
      put :update, id: @rr.id, business_validation_rule_result:{note:'abc', state:'Pass',message:'qrs'} 
      expect(response).to redirect_to validation_results_entry_path(@ent)
      @rr.reload
      expect(@rr.note).to eq 'abc'
      expect(@rr.state).to eq 'Pass'
      expect(@rr.message).to eq 'xyz'
    end
  end
end
