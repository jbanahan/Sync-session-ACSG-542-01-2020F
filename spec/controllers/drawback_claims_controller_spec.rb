require 'spec_helper'

describe DrawbackClaimsController do
  before :each do
    activate_authlogic
  end
  describe :index do
    before :each do
      @du = Factory(:drawback_user)
      @dc = Factory(:drawback_claim,:importer=>@du.company,:sent_to_customs_date=>1.year.ago)
      @dc2 = Factory(:drawback_claim,:importer=>@du.company)
      @dc_other = Factory(:drawback_claim,:sent_to_customs_date=>1.day.ago)
      UserSession.create! @du
    end
    it "should show claims based on DrawbackClaim.viewable" do
      User.any_instance.stub(:view_drawback?).and_return(true)
      DrawbackClaim.should_receive(:viewable).with(@du).and_return(DrawbackClaim.where("ID IN (?)",[@dc2,@dc_other]))
      get :index
      response.should be_success
      assigns(:claims).to_a.should == [@dc2,@dc_other]
    end
    it "should reject if user cannot view drawback" do
      User.any_instance.stub(:view_drawback?).and_return(false)
      get :index
      response.should be_redirect
      flash[:errors].should have(1).message
    end
  end
  describe :show do
    before :each do
      @d = Factory(:drawback_claim)
      @u = Factory(:user)
      UserSession.create! @u
    end
    it "should show to user with permission" do
      DrawbackClaim.any_instance.stub(:can_view?).and_return(true)
      get :show, :id=>@d.id
      response.should be_success
      assigns(:claim).should == @d
    end
    it "should redirect if no permission" do
      DrawbackClaim.any_instance.stub(:can_view?).and_return(false)
      get :show, :id=>@d.id
      response.should be_redirect
      assigns(:claim).should be_nil
      flash[:errors].should have(1).message
    end
  end
end
