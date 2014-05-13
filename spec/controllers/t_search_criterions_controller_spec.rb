require 'spec_helper'

describe TSearchCriterionsController do

  before :each do

  end

  describe :create do

    before :each do
      @sc = Factory(:search_criterion)
      @bvt = Factory(:business_validation_template)
      @bvr = Factory(:business_validation_rule)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :create, business_validation_template_id: @bvt.id, id: @sc.id
      expect(response).to be_redirect
    end

    it "should create the correct search criterion on a BVT" do
      u = Factory(:admin_user)
      sign_in_as u
      post :create, business_validation_template_id: @bvt.id,
                    search_criterion: {
                      "operator" => "eq",
                      "model_field_uid" => "ent_release_date",
                      "business_validation_template_id" => @bvt.id
                    }
      expect(response).to be_redirect
      new_sc = SearchCriterion.last
      new_sc.model_field_uid.should == "ent_release_date"
      new_sc.operator.should == "eq"
      new_sc.business_validation_template.should == @bvt
    end

  end

  describe :destroy do

    before :each do
      @sc = Factory(:search_criterion)
      @bvt = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      sign_in_as u
      post :destroy, id: @sc.id, business_validation_template_id: @bvt.id
      expect(response).to be_redirect
    end

    it "should delete the correct search criterion" do
      @sc.business_validation_template = @bvt; @sc.save!
      u = Factory(:admin_user)
      sign_in_as u
      post :destroy, id: @sc.id, business_validation_template_id: @bvt.id
      expect { SearchCriterion.find(@sc.id) }.to raise_error
    end

  end

end