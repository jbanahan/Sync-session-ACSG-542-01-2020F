require 'spec_helper'

class FakeController < ApplicationController; end

describe FakeController, :type => :controller do
  controller do
    include OpenChain::BusinessRuleValidationResultsSupport

    def validation_results
      generic_validation_results(Entry.find params[:id])
      render nothing: true unless performed?
    end
  end

  before(:each) do 
    @obj = Factory(:entry)
    @u = Factory(:user)
    sign_in_as @u
    @routes.draw { get "validation_results" => "anonymous#validation_results" }
  end

  describe :generic_validation_results do
    context "with HTML" do
      it "provides object to view if user has rights to object view and business validation results" do
        allow(@u).to receive(:view_business_validation_results?).and_return true
        allow_any_instance_of(Entry).to receive(:can_view?).with(@u).and_return true
        get :validation_results, id: @obj.id
        expect(assigns(:validation_object)).to eq @obj
        expect(response).to be_success
      end

      it "redirects with error if user can't view object" do
        allow(@u).to receive(:view_business_validation_results?).and_return true
        get :validation_results, id: @obj.id
        expect(response).to be_redirect
        expect(flash[:errors]).to include "You do not have permission to view this entry."
      end
      
      it "redirects with error if user can't view business results" do
        allow_any_instance_of(Entry).to receive(:can_view?).with(@u).and_return true
        get :validation_results, id: @obj.id
        expect(response).to be_redirect
        expect(flash[:errors]).to include "You do not have permission to view this entry."
      end
    end

    def create_validation_data user
      @obj = Factory(:entry, broker_reference: "123456")
      @bvt = Factory(:business_validation_template, module_type: 'Entry', name: "Entry rules")
      @bvr_1 = Factory(:business_validation_result, business_validation_template: @bvt, validatable: @obj, state: "Fail")
      @bvr_2 = Factory(:business_validation_result, business_validation_template: @bvt, validatable: @obj, state: "Pass")
      @bvru_1 = Factory(:business_validation_rule, business_validation_template: @bvt, name: "Rule no. 1", description: "desc of rule 1")
      @bvru_2 = Factory(:business_validation_rule, business_validation_template: @bvt, name: "Rule no. 2", description: "desc of rule 2")
      @bvru_3 = Factory(:business_validation_rule, business_validation_template: @bvt, name: "Rule no. 3", description: "desc of rule 3")
      
      @bvrr_1 = Factory(:business_validation_rule_result, business_validation_rule: @bvru_1, state: "Pass")
      @bvrr_1.business_validation_result = @bvr_1; @bvrr_1.save!
      
      @bvrr_2 = Factory(:business_validation_rule_result, business_validation_rule: @bvru_2, state: "Fail", note: "Why is this failing?", message: "This entry's no good!")
      @bvrr_2.business_validation_result = @bvr_1; @bvrr_2.save!
      
      @bvrr_3 = Factory(:business_validation_rule_result, business_validation_rule: @bvru_3, state: "Pass", overridden_at: DateTime.now, overridden_by: user)
      @bvrr_3.business_validation_result = @bvr_2; @bvrr_3.save!
    end

    context "with JSON" do
      before(:each) { create_validation_data @u }
      
      it "returns JSON object if user has right to view object and business validation results" do
        allow(@u).to receive(:view_business_validation_results?).and_return true
        allow_any_instance_of(Entry).to receive(:can_view?).with(@u).and_return true
        get :validation_results, id: @obj.id, :format => 'json'
        r = JSON.parse(response.body)["business_validation_result"]
        expect(r["object_number"]).to eq "123456"
        expect(r["bv_results"].first["state"]).to eq "Fail"
      end

      it "returns error if user can't view object" do
        allow(@u).to receive(:view_business_validation_results?).and_return true
        get :validation_results, id: @obj.id, :format => 'json'
        expect(JSON.parse(response.body)["error"]).to eq "You do not have permission to view this entry."
      end

      it "redirects with error if user can't view business results" do
        allow_any_instance_of(Entry).to receive(:can_view?).with(@u).and_return true
        get :validation_results, id: @obj.id, :format => 'json'
        expect(JSON.parse(response.body)["error"]).to eq "You do not have permission to view this entry."
      end
    end
  end
end

#harness for testing run_validations

class FakeJsonController < Api::V1::ApiController; end

describe FakeJsonController, :type => :controller do

  controller do
    include OpenChain::BusinessRuleValidationResultsSupport

    def validation_runner
      run_validations(Entry.find params[:id])
      render nothing: true unless performed?
    end
  end

  describe :run_validations do

    def create_validation_data user
      @obj = Factory(:entry, broker_reference: "123456")
      @bvt = Factory(:business_validation_template, module_type: 'Entry', name: "Entry rules")
      @bvr_1 = Factory(:business_validation_result, business_validation_template: @bvt, validatable: @obj, state: "Fail")
      @bvr_2 = Factory(:business_validation_result, business_validation_template: @bvt, validatable: @obj, state: "Pass")
      @bvru_1 = Factory(:business_validation_rule, business_validation_template: @bvt, name: "Rule no. 1", description: "desc of rule 1")
      @bvru_2 = Factory(:business_validation_rule, business_validation_template: @bvt, name: "Rule no. 2", description: "desc of rule 2")
      @bvru_3 = Factory(:business_validation_rule, business_validation_template: @bvt, name: "Rule no. 3", description: "desc of rule 3")
      
      @bvrr_1 = Factory(:business_validation_rule_result, business_validation_rule: @bvru_1, state: "Pass")
      @bvrr_1.business_validation_result = @bvr_1; @bvrr_1.save!
      
      @bvrr_2 = Factory(:business_validation_rule_result, business_validation_rule: @bvru_2, state: "Fail", note: "Why is this failing?", message: "This entry's no good!")
      @bvrr_2.business_validation_result = @bvr_1; @bvrr_2.save!
      
      @bvrr_3 = Factory(:business_validation_rule_result, business_validation_rule: @bvru_3, state: "Pass", overridden_at: DateTime.now, overridden_by: user)
      @bvrr_3.business_validation_result = @bvr_2; @bvrr_3.save!
    end
    
    before :each do 
      MasterSetup.get.update_attributes(:entry_enabled=>true)
      @u = Factory(:master_user,entry_view:true)
      allow_api_access @u
      @routes.draw { post "validation_runner" => "anonymous#validation_runner" }
    end

    it "delegates to BusinessValidationTemplate.create_results_for_object!" do
      BusinessValidationTemplate.destroy_all
      bvt = BusinessValidationTemplate.create!(module_type:'Entry')
      bvt.search_criterions.create! model_field_uid: "ent_entry_num", operator: "nq", value: "XXXXXXXXXX"
      ent = Factory(:entry)
      post :validation_runner, id: ent.id, format: "json"

      expect(bvt.business_validation_results.first.validatable).to eq ent
    end
    
    it "returns results hash" do
      obj = Factory(:entry)
      allow_any_instance_of(BusinessValidationResult).to receive(:can_view?).with(@u).and_return true
      post :validation_runner, id: obj.id, :format => 'json'
      expect(JSON.parse(response.body)["business_validation_result"]["single_object"]).to eq "Entry"
    end

    it "renders error if user doesn't have permission to view object" do
      obj = Factory(:entry)
      allow_any_instance_of(Entry).to receive(:can_view?).and_return false
      post :validation_runner, id: obj.id, :format => 'json'
      expect(JSON.parse(response.body)["errors"]).to eq ["You do not have permission to update validation results for this object."]
    end

    it "renders error if there are any rule results user doesn't have permission to edit" do
      create_validation_data @u
      @bvru_1.group = Factory(:group); @bvru_1.save!
      post :validation_runner, id: @obj.id, :format => 'json'
      expect(JSON.parse(response.body)["errors"]).to eq ["You do not have permission to update validation results for this object."]
    end
  end
end

describe OpenChain::BusinessRuleValidationResultsSupport do
  
  subject {
    Class.new {
      include OpenChain::BusinessRuleValidationResultsSupport
    }.new 
  }

  before :each do
    @u = Factory(:user, first_name: "Nigel", last_name: "Tufnel")
    allow(@u).to receive(:edit_business_validation_rule_results?).and_return true
  end

  def create_validation_data user
    @obj = Factory(:entry, broker_reference: "123456")
    @bvt = Factory(:business_validation_template, module_type: 'Entry', name: "Entry rules")
    @bvr_1 = Factory(:business_validation_result, business_validation_template: @bvt, validatable: @obj, state: "Fail")
    @bvr_2 = Factory(:business_validation_result, business_validation_template: @bvt, validatable: @obj, state: "Pass")
    @bvru_1 = Factory(:business_validation_rule, business_validation_template: @bvt, name: "Rule no. 1", description: "desc of rule 1")
    @bvru_2 = Factory(:business_validation_rule, business_validation_template: @bvt, name: "Rule no. 2", description: "desc of rule 2")
    @bvru_3 = Factory(:business_validation_rule, business_validation_template: @bvt, name: "Rule no. 3", description: "desc of rule 3")
    
    @bvrr_1 = Factory(:business_validation_rule_result, business_validation_rule: @bvru_1, state: "Pass")
    @bvrr_1.business_validation_result = @bvr_1; @bvrr_1.save!
    
    @bvrr_2 = Factory(:business_validation_rule_result, business_validation_rule: @bvru_2, state: "Fail", note: "Why is this failing?", message: "This entry's no good!")
    @bvrr_2.business_validation_result = @bvr_1; @bvrr_2.save!
    
    @bvrr_3 = Factory(:business_validation_rule_result, business_validation_rule: @bvru_3, state: "Pass", overridden_at: DateTime.now, overridden_by: user)
    @bvrr_3.business_validation_result = @bvr_2; @bvrr_3.save!
  end

  describe :results_to_hsh do

    before :each do
      create_validation_data(@u)
      @target = {
        object_number: "123456",
        state: "Fail",
        object_updated_at: @obj.updated_at,
        single_object: "Entry",
        can_run_validations: true,
        bv_results: [
          {
            id: @bvr_1.id,
            state: "Fail",
            template:{name:"Entry rules"},
            updated_at: @bvr_1.updated_at,
            rule_results:[
              {
                id: @bvrr_1.id,
                state: "Pass",
                rule: {name: "Rule no. 1", description: "desc of rule 1"},
                note: nil,
                message: nil,
                overridden_by: nil,
                overridden_at: nil,
                editable: true
                },
              {
                id: @bvrr_2.id,
                state: "Fail",
                rule: {name: "Rule no. 2", description: "desc of rule 2"},
                note: "Why is this failing?",
                message: "This entry's no good!",
                overridden_by: nil,
                overridden_at: nil,
                editable: true
                }
              ]
            },
          {
            id: @bvr_2.id,
            state: "Pass",
            template:{name:"Entry rules"},
            updated_at: @bvr_2.updated_at,
            rule_results:[
              {
                id: @bvrr_3.id,
                state: "Pass",
                rule: {name: "Rule no. 3", description: "desc of rule 3"},
                note: nil,
                message: nil,
                overridden_by: {full_name: "Nigel Tufnel"},
                overridden_at: @bvrr_3.overridden_at,
                editable: true
                }
              ]  
          }
        ]
      }
    end

    it "returns a hash of the business rule results associated with an object if the user has permission to view ALL of them" do
      allow_any_instance_of(BusinessValidationResult).to receive(:can_view?).with(@u).and_return true
      r = subject.results_to_hsh @u, @obj
      expect(r.to_json).to eq @target.to_json #to_json resolves millisecond discrepancy
    end

    it "returns nil if the business rule results have rule that user does not have permission to view" do
      r = subject.results_to_hsh @u, @obj
      expect(r).to be_nil
    end
  end
end