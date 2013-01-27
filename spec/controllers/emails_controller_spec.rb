require 'spec_helper'

describe EmailsController do
  before :each do 
    @u = Factory(:user)
    activate_authlogic
    UserSession.create! @u
  end
  describe "show" do
    before :each do
      @e = Factory(:email)
    end
    it 'should only show if you have permission to view' do
      Email.any_instance.stub(:can_view?).and_return false
      get :show, :id=>@e.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should get email" do
      Email.any_instance.stub(:can_view?).and_return true 
      get :show, :id=>@e.id
      response.should be_success
      assigns(:email).should == @e
    end
  end
  describe "assign" do
    before :each do 
      @e1 = Factory(:email)
      @e2 = Factory(:email)
      @e3 = Factory(:email)
    end
    it "should return error if user does not have permission"
    it "should make assignements and return success if user has permission" do
      Email.any_instance.stub(:can_edit?).and_return true
      post :assign, {''}
    end
  end
end
