require 'spec_helper'

describe DrawbackClaimsController do
  before :each do

  end
  describe :index do
    before :each do
      @du = Factory(:drawback_user)
      @dc = Factory(:drawback_claim,:importer=>@du.company,:sent_to_customs_date=>1.year.ago)
      @dc2 = Factory(:drawback_claim,:importer=>@du.company)
      @dc_other = Factory(:drawback_claim,:sent_to_customs_date=>1.day.ago)
      sign_in_as @du
    end
    it "redirects to advanced search" do
      get :index
      expect(response.location).to match "advanced_search"
    end
  end
  describe :show do
    before :each do
      @d = Factory(:drawback_claim)
      @u = Factory(:user)
      sign_in_as @u
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
      sign_in_as @u
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
      @h = {'id'=>@claim.id,'drawback_claim'=>{'dc_name'=>'newname'}}
      sign_in_as @u
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
      @h = {'drawback_claim'=>{'dc_imp_id'=>@c.id,'dc_name'=>'nm','dc_hmf_claimed'=>'10.04'}}
      sign_in_as @u
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
  describe :process_report do
    before :each do
      @u = Factory(:user)
      DrawbackClaim.any_instance.stub(:can_edit?).and_return(true)
      @claim = Factory(:drawback_claim)
      @att = Factory(:attachment,attachable:@claim)
      sign_in_as @u
    end
    it "should process export history" do
      eh = double(:export_history_parser)
      OpenChain::CustomHandler::DutyCalc::ExportHistoryParser.should_receive(:delay).and_return(eh)
      eh.should_receive(:process_excel_from_attachment).with(@att.id.to_s,@u.id)
      post :process_report, id:@claim.id, attachment_id:@att.id, process_type:'exphist'
      expect(response).to redirect_to @claim
    end
    it "should process claim audit" do
      ca = double(:claim_audit_parser)
      OpenChain::CustomHandler::DutyCalc::ClaimAuditParser.should_receive(:delay).and_return(ca)
      ca.should_receive(:process_excel_from_attachment).with(@att.id.to_s,@u.id)
      post :process_report, id:@claim.id, attachment_id:@att.id, process_type:'audrpt'
      expect(response).to redirect_to @claim
    end
  end
end
