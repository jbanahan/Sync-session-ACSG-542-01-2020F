require 'spec_helper'

describe SecurityFilingsController do
  before :each do
    activate_authlogic
    @u = Factory(:user)
    UserSession.create! @u
  end
  describe :show do
    before :each do
      @sf = Factory(:security_filing)
    end
    it "should allow user who can view the given filing" do
      SecurityFiling.any_instance.stub(:can_view?).and_return(true)
      get :show, :id=>@sf.id
      response.should be_success
      assigns(:security_filing).should == @sf
    end
    it "should not allow user who cannot view the given security filing" do
      SecurityFiling.any_instance.stub(:can_view?).and_return(false)
      get :show, :id=>@sf.id
      response.should redirect_to request.referrer
      assigns(:security_filing).should be_nil
      flash[:errors].should have(1).message
    end
  end
end
