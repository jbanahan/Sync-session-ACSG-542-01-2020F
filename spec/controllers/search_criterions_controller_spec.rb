require 'spec_helper'

describe SearchCriterionsController do

  before :each do
    activate_authlogic
  end

  describe :create do

    before :each do
      @sc = Factory(:search_criterion)
      @bvt = Factory(:business_validation_template)
      @bvr = Factory(:business_validation_rule)
    end

    it "should require admin" do
      u = Factory(:user)
      UserSession.create! u
      post :create, id: @sc.id
      expect(response).to be_redirect
    end

    it "should create the correct search criterion on a BVT" do
      u = Factory(:admin_user)
      UserSession.create! u
      post :create, id: @sc.id,
                    search_criterion: {
                      "operator" => "eq",
                      "model_field_uid" => "ent_release_date",
                      "business_validation_template_id" => @bvt.id
                    }
      expect(response).to be_redirect
      response.request.filtered_parameters["id"].to_i.should == @sc.id
      expect { SearchCriterion.find(@sc.id) }.to_not raise_error
    end

    it "should create the correct search criterion on a BVR" do
      @bvr.business_validation_template = @bvt; @bvt.save!
      u = Factory(:admin_user)
      UserSession.create! u
      post :create, id: @sc.id,
                    search_criterion: {
                      "operator" => "eq",
                      "model_field_uid" => "ent_release_date",
                      "business_validation_rule_id" => @bvr.id
                    }
      expect(response).to be_redirect
      response.request.filtered_parameters["id"].to_i.should == @sc.id
      expect { SearchCriterion.find(@sc.id) }.to_not raise_error
    end

  end

  describe :destroy do

    before :each do
      @sc = Factory(:search_criterion)
      @bvt = Factory(:business_validation_template)
    end

    it "should require admin" do
      u = Factory(:user)
      UserSession.create! u
      post :destroy, id: @sc.id
      expect(response).to be_redirect
    end

    it "should delete the correct search criterion" do
      @sc.business_validation_template = @bvt; @sc.save!
      u = Factory(:admin_user)
      UserSession.create! u
      post :destroy, id: @sc.id
      expect { SearchCriterion.find(@sc.id) }.to raise_error
    end

  end

end