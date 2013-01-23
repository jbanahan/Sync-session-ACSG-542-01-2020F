require 'spec_helper'

describe AttachmentArchiveManifestsController do
  before :each do
    @u = Factory(:user)
    User.any_instance.stub(:view_attachment_archives?).and_return(true)
    activate_authlogic
    UserSession.create! @u
  end
  describe :create do
    it "should create manifest and delay manifest generation" do
      d = mock("delayed_job")
      d.should_receive(:make_manifest!)
      AttachmentArchiveManifest.any_instance.should_receive(:delay).and_return(d)
      post :create, :company_id=>@u.company.id.to_s
      response.should be_success
      m = AttachmentArchiveManifest.find_by_company_id(@u.company.id)
      JSON.parse(response.body).should == {'id'=>m.id}
    end
    it "should fail if user cannot view archives" do
      User.any_instance.stub(:view_attachment_archives?).and_return(false)
      post :create, :company_id=>@u.company.id.to_s
      response.should be_redirect
      AttachmentArchiveManifest.first.should be_nil
      flash[:errors].should_not be_empty
    end
  end
  describe :download do
    before :each do
      @m = @u.company.attachment_archive_manifests.create!
    end
    it "should respond with 204 if manifest not done" do
      get :download, :company_id=>@u.company.id, :id=>@m.id
      response.status.should == 204
    end
    it "should respond with 200 and attachment if done" do
      @m.make_manifest!
      get :download, :company_id=>@u.company.id, :id=>@m.id
      response.location.should match /s3.*attachment/
    end
    it "should fail if user cannot view " do
      User.any_instance.stub(:view_attachment_archives?).and_return(false)
      get :download, :company_id=>@u.company.id, :id=>@m.id
      response.should redirect_to request.referrer
      flash[:errors].should_not be_empty
    end
  end
end
