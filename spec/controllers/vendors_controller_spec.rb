require 'spec_helper'

describe VendorsController do
  before :each do
    @u = Factory(:user)
    sign_in_as @u
  end
  describe :show do
    it "should error if user cannot view company" do
      Company.any_instance.stub(:can_view?).and_return false
      get :show, id: @u.company.id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /view/
    end
    it "should render if user can view company" do
      Company.any_instance.stub(:can_view?).and_return true
      get :show, id: @u.company.id.to_s
      expect(response).to be_success
      expect(assigns(:company)).to eq @u.company
    end
  end

  describe :locations do
    it "should error if user cannot view company" do
      Company.any_instance.stub(:can_view?).and_return false
      get :locations, id: @u.company.id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /view/
    end
    it "should render if user can view company" do
      Company.any_instance.stub(:can_view?).and_return true
      get :locations, id: @u.company.id.to_s
      expect(response).to be_success
      expect(assigns(:company)).to eq @u.company
    end

  end

  describe :orders do
    it "should error if user cannot view company" do
      Company.any_instance.stub(:can_view?).and_return false
      get :orders, id: @u.company.id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /view/
    end
    it "should search_secure orders" do
      @u.company.update_attributes(vendor:true)
      o = Factory(:order,vendor_id:@u.company.id)
      o_not_found = Factory(:order)
      get :orders, id: @u.company.id.to_s
      expect(response).to be_success
      expect(assigns[:orders]).to eq [o]
    end
  end

  describe :survey_responses do
    it "should error if user cannot view company" do
      Company.any_instance.stub(:can_view?).and_return false
      get :survey_responses, id: @u.company_id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /view/
    end
    it "should search_secure surveys" do
      c = @u.company
      @u.update_attributes(survey_view:true)
      sr = Factory(:survey_response,survey:Factory(:survey,company:@u.company),base_object:c)
      sr2 = Factory(:survey_response,user:@u,base_object:c)
      sr_dont_find = Factory(:survey_response,base_object:c)
      get :survey_responses, id: @u.company_id.to_s
      expect(response).to be_success
      expect(assigns[:survey_responses].to_a).to eq [sr,sr2]
    end
  end
end