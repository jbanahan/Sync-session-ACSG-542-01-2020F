require 'spec_helper'

describe AttachmentArchiveManifestsController do
  before :each do
    @u = Factory(:user)
    User.any_instance.stub(:view_attachment_archives?).and_return(true)

    sign_in_as @u
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
    it "should respond with a 204 if the manifest doesn't exist in s3" do
      # The excessive mocking is because you can't really reliably 
      # test a situation where the attachment record exists but the actual
      # data isn't in S3 yet.
      attachment = double()
      company = double()
      manifests = double()
      manifest = double()
      attach = double()
      Company.should_receive(:find).with("#{@u.company.id}").and_return(company)
      company.should_receive(:attachment_archive_manifests).and_return(manifests)
      manifests.should_receive(:find).with("#{@m.id}").and_return(manifest)
      manifest.should_receive(:attachment).any_number_of_times.and_return(attachment)
      attachment.should_receive(:attached).any_number_of_times.and_return(attach)
      attach.should_receive(:exists?).and_return(false)

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
