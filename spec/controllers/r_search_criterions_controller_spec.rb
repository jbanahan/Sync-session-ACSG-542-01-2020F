require 'spec_helper'

describe RSearchCriterionsController do

  describe "create" do

    before :each do
      @sc = Factory(:search_criterion)
      @bvt = Factory(:business_validation_template)
      @bvr = Factory(:business_validation_rule)
      @bvr.business_validation_template = @bvt; @bvr.save!
      @sc.business_validation_rule = @bvr; @sc.save!
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :create, business_validation_rule_id: @bvr.id, business_validation_template_id: @bvt.id, 
                    search_criterion: {
                      "operator" => "eq",
                      "model_field_uid" => "ent_release_date"
                    }
      expect(response).to be_redirect
    end

    it "should create the correct search criterion on a BVR" do
      u = Factory(:admin_user)
      sign_in_as u
      post :create, business_validation_rule_id: @bvr.id, business_validation_template_id: @bvt.id,
                    search_criterion: {
                      "operator" => "eq",
                      "model_field_uid" => "ent_release_date"
                    }
      expect(response).to be_redirect
      new_sc = SearchCriterion.last
      expect(new_sc.model_field_uid).to eq("ent_release_date")
      expect(new_sc.operator).to eq("eq")
      expect(new_sc.business_validation_rule.id).to eq(@bvr.id)
      expect(new_sc.business_validation_rule.business_validation_template.id).to eq(@bvt.id)
    end

  end

  describe "destroy" do

    before :each do
      @sc = Factory(:search_criterion)
      @bvt = Factory(:business_validation_template)
      @bvr = Factory(:business_validation_rule)
      @bvr.business_validation_template = @bvt; @bvr.save!
      @sc.business_validation_rule = @bvr; @sc.save!
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :destroy, id: @sc.id, business_validation_template_id: @bvt.id, business_validation_rule_id: @bvr.id
      expect(response).to be_redirect
    end

    it "should delete the correct search criterion" do
      u = Factory(:admin_user)
      sign_in_as u
      post :destroy, id: @sc.id, business_validation_template_id: @bvt.id, business_validation_rule_id: @bvr.id
      expect { SearchCriterion.find(@sc.id) }.to raise_error
    end

  end
end