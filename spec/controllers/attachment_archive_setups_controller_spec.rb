describe AttachmentArchiveSetupsController do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:user) }
  let(:company) { create(:company) }

  describe "generate_packets" do
    it "fails if user not admin" do
      sign_in_as user
      post :generate_packets, company_id: company.id
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end

    it "fails if a start date or a csv file is not provided" do
      sign_in_as admin
      post :generate_packets, company_id: company.id
      expect(flash[:errors]).to eq(["Either the start date or csv file must be provided."])
    end

    it "delays the packet generation" do
      sign_in_as admin
      expect(OpenChain::ArchivePacketGenerator).to receive(:delay).and_return(OpenChain::ArchivePacketGenerator)
      post :generate_packets, company_id: company.id, start_date: Time.zone.today
    end

    it "succeeds if user admin" do
      sign_in_as admin
      post :generate_packets, company_id: company.id, start_date: Time.zone.today
      expect(flash[:notices]).to eq(["Your packet generation request has been received. You will receive a message when it is complete."])
    end
  end

  describe "new" do
    it "fails if user not admin" do
      sign_in_as user
      get :new, company_id: company.id
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end

    it "succeeds if user admin" do
      sign_in_as admin
      get :new, company_id: company.id
      expect(response).to be_success
      expect(assigns(:company)).to eq(company)
    end
  end

  describe "edit" do
    before do
      company.create_attachment_archive_setup(start_date: Time.zone.now)
    end

    it "fails if user not admin" do
      sign_in_as user
      get :edit, company_id: company.id, id: company.attachment_archive_setup.id
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end

    it "succeeds if user admin" do
      sign_in_as admin
      get :edit, company_id: company.id, id: company.attachment_archive_setup.id
      expect(response).to be_success
      expect(assigns(:company)).to eq(company)
    end
  end

  describe "create" do
    it "succeeds if user admin" do
      sign_in_as admin
      target_date = Date.new(2011, 12, 1)
      post :create, company_id: company.id, attachment_archive_setup: {start_date: target_date.strftime("%Y-%m-%d")}
      company.reload
      expect(company.attachment_archive_setup.start_date).to eq(target_date)
      expect(response).to redirect_to [company, company.attachment_archive_setup]
      expect(flash[:notices]).to eq(["Your setup was successfully created."])
    end

    it "fails if the output path has an erronious variable" do
      sign_in_as admin
      target_date = Date.new(2011, 12, 1)
      post :create, company_id: company.id, attachment_archive_setup: {start_date: target_date.strftime("%Y-%m-%d"),
                                                                       output_path: "{{entry.not_valid}}"}
      company.reload
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq(["Archive setup was not saved. 'Archive Output Path' was not valid."])
    end

    it "fails if company already has record" do
      sign_in_as admin
      company.create_attachment_archive_setup(start_date: Time.zone.now)
      target_date = Date.new(2011, 12, 1)
      post :create, company_id: company.id, attachment_archive_setup: {start_date: target_date.strftime("%Y-%m-%d")}
      company.reload
      expect(company.attachment_archive_setup.start_date).to eq(0.seconds.ago.to_date)
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq(["This company already has an attachment archive setup."])
    end

    it "fails if user not admin" do
      sign_in_as user
      target_date = Date.new(2011, 12, 1)
      post :create, company_id: company.id, attachment_archive_setup: {start_date: target_date.strftime("%Y-%m-%d")}
      company.reload
      expect(company.attachment_archive_setup).to be_nil
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq(["You do not have permission to access this page."])
    end

    it "blanks the order, include only, and real time attributes if combined attribute is not checked" do
      sign_in_as admin
      target_date = Date.new(2011, 12, 1)
      post :create, company_id: company.id, attachment_archive_setup: {start_date: target_date.strftime("%Y-%m-%d"),
                                                                       combine_attachments: "0", include_only_listed_attachments: "1",
                                                                       send_in_real_time: "1", combined_attachment_order: "A\nB\nC"}
      company.reload
      expect(company.attachment_archive_setup.start_date).to eq target_date
      expect(company.attachment_archive_setup.combine_attachments).to be_falsey
      expect(company.attachment_archive_setup.combined_attachment_order).to eq ""
      expect(company.attachment_archive_setup.include_only_listed_attachments).to eq false
      expect(company.attachment_archive_setup.send_in_real_time).to eq false
      expect(response).to redirect_to [company, company.attachment_archive_setup]
    end
  end

  describe "update" do
    before do
      company.create_attachment_archive_setup(start_date: Time.zone.now)
    end

    it "succeeds if user is admin" do
      sign_in_as admin
      target_date = Date.new(2011, 12, 1)
      post :update, company_id: company.id, id: company.attachment_archive_setup.id,
                    attachment_archive_setup: {start_date: target_date.strftime("%Y-%m-%d"), combine_attachments: "1",
                                               combined_attachment_order: "A\nB\nC"}
      company.reload
      expect(company.attachment_archive_setup.start_date).to eq target_date
      expect(company.attachment_archive_setup.combine_attachments).to be_truthy
      expect(company.attachment_archive_setup.combined_attachment_order).to eq "A\nB\nC"
      expect(response).to redirect_to [company, company.attachment_archive_setup]
      expect(flash[:notices]).to eq(["Your setup was successfully updated."])
    end

    it "fails if the output path has an erronious variable" do
      sign_in_as admin
      target_date = Date.new(2011, 12, 1)
      post :update, company_id: company.id, id: company.attachment_archive_setup.id,
                    attachment_archive_setup: {start_date: target_date.strftime("%Y-%m-%d"), output_path: "{{entry.not_valid}}"}
      company.reload
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq(["Archive setup was not saved. 'Archive Output Path' was not valid."])
    end

    it "fails if user not admin" do
      sign_in_as user
      target_date = Date.new(2011, 12, 1)
      post :update, company_id: company.id, id: company.attachment_archive_setup.id, attachment_archive_setup: {start_date: target_date.strftime("%Y-%m-%d")}
      company.reload
      expect(company.attachment_archive_setup.start_date).to eq 0.seconds.ago.to_date
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).to eq ["You do not have permission to access this page."]
    end

    it "blanks the order, include only, and real time attributes if combined attribute is not checked" do
      sign_in_as admin
      target_date = Date.new(2011, 12, 1)
      post :update, company_id: company.id, id: company.attachment_archive_setup.id,
                    attachment_archive_setup: {start_date: target_date.strftime("%Y-%m-%d"), combine_attachments: "0",
                                               include_only_listed_attachments: "1", send_in_real_time: "1",
                                               combined_attachment_order: "A\nB\nC"}
      company.reload
      expect(company.attachment_archive_setup.start_date).to eq target_date
      expect(company.attachment_archive_setup.combine_attachments).to be_falsey
      expect(company.attachment_archive_setup.combined_attachment_order).to eq ""
      expect(company.attachment_archive_setup.include_only_listed_attachments).to eq false
      expect(company.attachment_archive_setup.send_in_real_time).to eq false
      expect(response).to redirect_to [company, company.attachment_archive_setup]
    end
  end
end
