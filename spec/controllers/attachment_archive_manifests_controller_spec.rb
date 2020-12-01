describe AttachmentArchiveManifestsController do
  before :each do
    @u = FactoryBot(:user)
    allow_any_instance_of(User).to receive(:view_attachment_archives?).and_return(true)

    sign_in_as @u
  end
  describe "create" do
    it "should create manifest and delay manifest generation" do
      d = double("delayed_job")
      expect(d).to receive(:make_manifest!)
      expect_any_instance_of(AttachmentArchiveManifest).to receive(:delay).and_return(d)
      post :create, :company_id=>@u.company.id.to_s
      expect(response).to be_success
      m = AttachmentArchiveManifest.find_by(company: @u.company)
      expect(JSON.parse(response.body)).to eq({'id'=>m.id})
    end
    it "should fail if user cannot view archives" do
      allow_any_instance_of(User).to receive(:view_attachment_archives?).and_return(false)
      post :create, :company_id=>@u.company.id.to_s
      expect(response).to be_redirect
      expect(AttachmentArchiveManifest.first).to be_nil
      expect(flash[:errors]).not_to be_empty
    end
  end
  describe "download" do
    before :each do
      @m = @u.company.attachment_archive_manifests.create!
    end
    it "should respond with 204 if manifest not done" do
      get :download, :company_id=>@u.company.id, :id=>@m.id
      expect(response.status).to eq(204)
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
      expect(Company).to receive(:find).with("#{@u.company.id}").and_return(company)
      expect(company).to receive(:attachment_archive_manifests).and_return(manifests)
      expect(manifests).to receive(:find).with("#{@m.id}").and_return(manifest)
      allow(manifest).to receive(:attachment).and_return(attachment)
      allow(attachment).to receive(:attached).and_return(attach)
      expect(attach).to receive(:exists?).and_return(false)

      get :download, :company_id=>@u.company.id, :id=>@m.id
      expect(response.status).to eq(204)
    end
    it "should respond with 200 and attachment if done", paperclip: true, s3: true do
      @m.make_manifest!
      get :download, :company_id=>@u.company.id, :id=>@m.id
      expect(response.location).to match /s3.*attachment/
    end
    it "should fail if user cannot view " do
      allow_any_instance_of(User).to receive(:view_attachment_archives?).and_return(false)
      get :download, :company_id=>@u.company.id, :id=>@m.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).not_to be_empty
    end
  end
end
