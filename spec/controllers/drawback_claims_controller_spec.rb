require 'spec_helper'

describe DrawbackClaimsController do
  before :each do

  end
  describe "index" do
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
  describe "show" do
    before :each do
      @d = Factory(:drawback_claim)
      @u = Factory(:user)
      sign_in_as @u
    end
    it "should show to user with permission" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_view?).and_return(true)
      get :show, :id=>@d.id
      expect(response).to be_success
      expect(assigns(:claim)).to eq(@d)
    end
    it "should redirect if no permission" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_view?).and_return(false)
      get :show, :id=>@d.id
      expect(response).to be_redirect
      expect(assigns(:claim)).to be_nil
      expect(flash[:errors].size).to eq(1)
    end
  end
  describe "edit" do
    before :each do
      @claim = Factory(:drawback_claim)
      @u = Factory(:user)
      sign_in_as @u
    end
    it "should show claim" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return(true)
      get :edit, :id=>@claim.id
      expect(response).to be_success
      expect(assigns(:drawback_claim)).to eq(@claim)
    end
    it "should not show claim if user does not have permission to edit" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return(false)
      get :edit, :id=>@claim.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].size).to eq(1)
    end
  end
  describe "update" do
    before :each do
      @u = Factory(:user)
      @claim = Factory(:drawback_claim)
      @h = {'id'=>@claim.id,'drawback_claim'=>{'dc_name'=>'newname'}}
      sign_in_as @u
    end
    it "should update claim" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return(true)
      put :update, @h
      expect(response).to redirect_to @claim
      expect(flash[:notices].size).to eq(1)
      @claim.reload
      expect(@claim.name).to eq('newname')
    end
    it "should not update if user doesn't have permission" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return(false)
      put :update, @h
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].size).to eq(1)
      expect(DrawbackClaim.find(@claim.id).name).to eq(@claim.name)
    end
  end
  describe "create" do
    before :each do
      @u = Factory(:user)
      @c = Factory(:company)
      @h = {'drawback_claim'=>{'dc_imp_id'=>@c.id,'dc_name'=>'nm','dc_hmf_claimed'=>'10.04'}}
      sign_in_as @u
    end
    it "should save new claim" do
      allow_any_instance_of(User).to receive(:edit_drawback?).and_return(true)
      post :create, @h
      expect(response).to redirect_to DrawbackClaim
      expect(flash[:notices].size).to eq(1)
      d = DrawbackClaim.first
      expect(d.importer).to eq @c
      expect(d.name).to eq 'nm'
      expect(d.hmf_claimed).to eq 10.04
    end
    it "should fail if user cannot edit drawback" do
      allow_any_instance_of(User).to receive(:edit_drawback?).and_return(false)
      post :create, @h
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].size).to eq(1)
      expect(DrawbackClaim.all).to be_empty
    end
  end
  describe "process_report" do
    before :each do
      @u = Factory(:user)
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return(true)
      @claim = Factory(:drawback_claim)
      @att = Factory(:attachment,attachable:@claim)
      sign_in_as @u
    end
    it "should process export history" do
      eh = double(:export_history_parser)
      expect(OpenChain::CustomHandler::DutyCalc::ExportHistoryParser).to receive(:delay).and_return(eh)
      expect(eh).to receive(:process_from_attachment).with(@att.id.to_s,@u.id)
      post :process_report, id:@claim.id, attachment_id:@att.id, process_type:'exphist'
      expect(response).to redirect_to @claim
    end
    it "should process claim audit" do
      ca = double(:claim_audit_parser)
      expect(OpenChain::CustomHandler::DutyCalc::ClaimAuditParser).to receive(:delay).and_return(ca)
      expect(ca).to receive(:process_from_attachment).with(@att.id.to_s,@u.id)
      post :process_report, id:@claim.id, attachment_id:@att.id, process_type:'audrpt'
      expect(response).to redirect_to @claim
    end
  end
  describe "audit_report" do
    before :each do
      @u = Factory(:user, company: Factory(:master_company))
      @claim = Factory(:drawback_claim)
      sign_in_as @u
    end

    it "only runs for drawback viewers" do
      expect_any_instance_of(OpenChain::Report::DrawbackAuditReport).not_to receive(:run_and_attach)
      post :audit_report, id: @claim.id
      expect(flash[:errors].count).to eq 1
    end

    it "runs report" do
      allow(@u).to receive(:view_drawback?).and_return true
      expect_any_instance_of(OpenChain::Report::DrawbackAuditReport).to receive(:run_and_attach).with(@u, @claim.id)
      post :audit_report, id: @claim.id
      expect(flash[:notices]).to include "Report is being processed.  You'll receive a system message when it is complete."
    end
  end

    describe 'validation_results' do
    before :each do
      MasterSetup.get.update_attributes(:drawback_enabled => true)
      @u = Factory(:drawback_user)
      @u.company.update_attributes! master: true
      sign_in_as @u

      @dc = Factory(:drawback_claim, name:'test_dc')
      @rule_result = Factory(:business_validation_rule_result)
      @bvr = @rule_result.business_validation_result
      @bvr.state = 'Fail'
      @bvr.validatable = @dc
      @bvr.save!
    end
    it "should render page" do
      get :validation_results, id: @dc.id
      expect(response).to be_success
      expect(assigns(:validation_object)).to eq @dc
    end
    it "should render json" do
      @bvr.business_validation_template.update_attributes(name:'myname')
      @rule_result.business_validation_rule.update_attributes(name:'rulename',description:'ruledesc')
      @rule_result.note = 'abc'
      @rule_result.state = 'Pass'
      @rule_result.overridden_by = @u
      @rule_result.overridden_at = Time.now
      @rule_result.save!
      @rule_result.reload #fixes time issue
      get :validation_results, id: @dc.id, format: :json
      expect(response).to be_success
      h = JSON.parse(response.body)['business_validation_result']
      expect(h['object_number']).to eq @dc.name
      expect(h['single_object']).to eq "DrawbackClaim"
      expect(h['state']).to eq @bvr.state
      bv_results = h['bv_results']
      expect(bv_results.length).to eq 1
      bvr = bv_results.first
      expect(bvr['id']).to eq @bvr.id
      expect(bvr['state']).to eq @bvr.state
      expect(bvr['template']['name']).to eq 'myname'
      expect(bvr['rule_results'].length).to eq 1
      rr = bvr['rule_results'].first
      expect(rr['id']).to eq @rule_result.id
      expect(rr['rule']['name']).to eq 'rulename'
      expect(rr['rule']['description']).to eq 'ruledesc'
      expect(rr['note']).to eq 'abc'
      expect(rr['overridden_by']['full_name']).to eq @u.full_name
      expect(Time.parse(rr['overridden_at'])).to eq @rule_result.overridden_at
    end

  end
  describe 'clear_claim_audits' do
    before :each do
      @u = Factory(:drawback_user)
      sign_in_as @u
      @c = Factory(:drawback_claim)
      @ca = @c.drawback_claim_audits.create!
    end
    it "should restrict to edit_drawback?" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return false
      expect{delete :clear_claim_audits, id: @c.id}.to_not change(DrawbackClaimAudit,:count)
      expect(flash[:errors].size).to eq 1
    end
    it "should clear claim audit" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
      expect{
        delete :clear_claim_audits, id: @c.id
      }.to change(DrawbackClaimAudit,:count).from(1).to(0)
    end
  end
  describe 'clear_export_histories' do
    before :each do
      @u = Factory(:drawback_user)
      sign_in_as @u
      @c = Factory(:drawback_claim)
      @ca = @c.drawback_export_histories.create!
    end
    it "should restrict to edit_drawback?" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return false
      expect{delete :clear_export_histories, id: @c.id}.to_not change(DrawbackExportHistory,:count)
      expect(flash[:errors].size).to eq 1
    end
    it "should clear claim audit" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
      expect{
        delete :clear_export_histories, id: @c.id
      }.to change(DrawbackExportHistory,:count).from(1).to(0)
    end
  end
end
