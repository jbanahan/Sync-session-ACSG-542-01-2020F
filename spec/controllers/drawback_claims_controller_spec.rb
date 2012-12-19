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
  describe :edit do
    before :each do
      @claim = Factory(:drawback_claim)
      @u = Factory(:user)
    end
    it "should show claim" do
      DrawbackClaim.any_instance.stub(:can_edit?).and_return(true)
      get :edit, :id=>@claim.id
      response.should be_success
      assigns(:drawback_claim).should == @claim
    end
    it "should not show claim if user does not have permission to edit" do
      DrawbackClaim.any_instance.stub(:can_edit?).and_return(false)
      get :edit, :id=>@claim.id
      response.should redirect_to request.referrer
      flash[:errors].should have(1).message
    end
  end
  describe :update do
    before :each do
      @u = Factory(:user)
      @claim = Factory(:drawback_claim)
      @h = {'id'=>@claim.id,'drawback_claim'=>{'name'=>'newname'}}
      UserSession.create! @u
    end
    it "should update claim" do
      DrawbackClaim.any_instance.stub(:can_edit?).and_return(true)
      put :update, @h
      response.should redirect_to @claim
      flash[:notices].should have(1).message
      @claim.reload
      @claim.name.should == 'newname'
    end
    it "should not update if user doesn't have permission" do
      DrawbackClaim.any_instance.stub(:can_edit?).and_return(false)
      put :update, @h
      response.should redirect_to request.referrer
      flash[:errors].should have(1).message
      DrawbackClaim.find(@claim.id).name.should == @claim.name
    end
  end
  describe :create do
    before :each do
      @u = Factory(:user)
      @c = Factory(:company)
      @h = {'drawback_claim'=>{'importer_id'=>@c.id,'name'=>'nm','hmf_claimed'=>'10.04'}}
      UserSession.create! @u
    end
    it "should save new claim" do
      User.any_instance.stub(:edit_drawback?).and_return(true)
      post :create, @h
      response.should redirect_to DrawbackClaim
      flash[:notices].should have(1).message
      d = DrawbackClaim.first
      d.importer.should == @c
      d.name.should == 'nm'
      d.hmf_claimed.should == 10.04
    end
    it "should fail if user cannot edit drawback" do
      User.any_instance.stub(:edit_drawback?).and_return(false)
      post :create, @h
      response.should redirect_to request.referrer
      flash[:errors].should have(1).message
      DrawbackClaim.all.should be_empty
    end
  end
end
