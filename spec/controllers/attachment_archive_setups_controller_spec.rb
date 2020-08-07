describe AttachmentArchiveSetupsController do
  before :each do
    @admin = Factory(:admin_user)
    @user = Factory(:user)
    @c = Factory(:company)
  end

  describe "generate_packets" do
    it "should fail if user not admin" do
      sign_in_as @user
      post :generate_packets, :company_id=>@c.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end

    it "should fail if a start date or a csv file is not provided" do
      sign_in_as @admin
      post :generate_packets, :company_id=>@c.id
      expect(flash[:errors]).to eq(["Either the start date or csv file must be provided."])
    end

    it "delays the packet generation" do
      sign_in_as @admin
      expect(OpenChain::ArchivePacketGenerator).to receive(:delay).and_return(OpenChain::ArchivePacketGenerator)
      post :generate_packets, :company_id=>@c.id, :start_date=>Time.zone.today
    end

    it "should succeed if user admin" do
      sign_in_as @admin
      post :generate_packets, :company_id=>@c.id, :start_date=>Time.zone.today
      expect(flash[:notices]).to eq(["Your packet generation request has been received. You will receive a message when it is complete."])
    end
  end

  describe "new" do
    it "should fail if user not admin" do
      sign_in_as @user
      get :new, :company_id=>@c.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end

    it "should succeed if user admin" do
      sign_in_as @admin
      get :new, :company_id=>@c.id
      expect(response).to be_success
      expect(assigns(:company)).to eq(@c)
    end
  end

  describe "edit" do
    before :each do
      @c.create_attachment_archive_setup(:start_date=>Time.now)
    end

    it "should fail if user not admin" do
      sign_in_as @user
      get :edit, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end

    it "should succeed if user admin" do
      sign_in_as @admin
      get :edit, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id
      expect(response).to be_success
      expect(assigns(:company)).to eq(@c)
    end
  end

  describe "create" do
    it "should succeed if user admin" do
      sign_in_as @admin
      target_date = Date.new(2011, 12, 1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq(target_date)
      expect(response).to redirect_to [@c, @c.attachment_archive_setup]
      expect(flash[:notices]).to eq(["Your setup was successfully created."])
    end

    it "should fail if the output path has an erronious variable" do
      sign_in_as @admin
      target_date = Date.new(2011, 12, 1)
      post :create, :company_id => @c.id, :attachment_archive_setup=>{start_date: target_date.strftime("%Y-%m-%d"),
                                                                      output_path: "{{entry.not_valid}}"}
      @c.reload
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["Archive setup was not saved. 'Archive Output Path' was not valid."])
    end

    it "should fail if company already has record" do
      sign_in_as @admin
      @c.create_attachment_archive_setup(:start_date=>Time.now)
      target_date = Date.new(2011, 12, 1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq(0.seconds.ago.to_date)
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["This company already has an attachment archive setup."])
    end

    it "should fail if user not admin" do
      sign_in_as @user
      target_date = Date.new(2011, 12, 1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      expect(@c.attachment_archive_setup).to be_nil
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end

    it "blanks the order, include only, and real time attributes if combined attribute is not checked" do
      sign_in_as @admin
      target_date = Date.new(2011, 12, 1)
      post :create, :company_id=>@c.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d"), :combine_attachments=>"0", :include_only_listed_attachments=>"1", :send_in_real_time=>"1", :combined_attachment_order=>"A\nB\nC"}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq target_date
      expect(@c.attachment_archive_setup.combine_attachments).to be_falsey
      expect(@c.attachment_archive_setup.combined_attachment_order).to eq ""
      expect(@c.attachment_archive_setup.include_only_listed_attachments).to eq false
      expect(@c.attachment_archive_setup.send_in_real_time).to eq false
      expect(response).to redirect_to [@c, @c.attachment_archive_setup]
    end
  end

  describe "update" do
    before :each do
      @c.create_attachment_archive_setup(:start_date=>Time.now)
    end

    it "should succeed if user is admin" do
      sign_in_as @admin
      target_date = Date.new(2011, 12, 1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d"), :combine_attachments=>"1", :combined_attachment_order=>"A\nB\nC"}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq target_date
      expect(@c.attachment_archive_setup.combine_attachments).to be_truthy
      expect(@c.attachment_archive_setup.combined_attachment_order).to eq "A\nB\nC"
      expect(response).to redirect_to [@c, @c.attachment_archive_setup]
      expect(flash[:notices]).to eq(["Your setup was successfully updated."])
    end

    it "should fail if the output path has an erronious variable" do
      sign_in_as @admin
      target_date = Date.new(2011, 12, 1)
      post :update, :company_id => @c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{start_date: target_date.strftime("%Y-%m-%d"),
                                                                                                           output_path: "{{entry.not_valid}}"}
      @c.reload
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq(["Archive setup was not saved. 'Archive Output Path' was not valid."])
    end

    it "should fail if user not admin" do
      sign_in_as @user
      target_date = Date.new(2011, 12, 1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d")}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq 0.seconds.ago.to_date
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to eq ["You do not have permission to access this page."]
    end

    it "blanks the order, include only, and real time attributes if combined attribute is not checked" do
      sign_in_as @admin
      target_date = Date.new(2011, 12, 1)
      post :update, :company_id=>@c.id, :id=>@c.attachment_archive_setup.id, :attachment_archive_setup=>{:start_date=>target_date.strftime("%Y-%m-%d"), :combine_attachments=>"0", :include_only_listed_attachments=>"1", :send_in_real_time=>"1", :combined_attachment_order=>"A\nB\nC"}
      @c.reload
      expect(@c.attachment_archive_setup.start_date).to eq target_date
      expect(@c.attachment_archive_setup.combine_attachments).to be_falsey
      expect(@c.attachment_archive_setup.combined_attachment_order).to eq ""
      expect(@c.attachment_archive_setup.include_only_listed_attachments).to eq false
      expect(@c.attachment_archive_setup.send_in_real_time).to eq false
      expect(response).to redirect_to [@c, @c.attachment_archive_setup]
    end
  end
end
