describe PowerOfAttorneysController do
  let(:company) { Factory(:company) }
  let(:user) { Factory(:user, company: company) }
  let!(:power_of_attorney) { Factory(:power_of_attorney, user: user, company: company) }

  before do
    sign_in_as user
  end

  describe "GET index" do
    it "assigns all power_of_attorneys as power_of_attorney" do
      expect(user).to receive(:view_power_of_attorneys?).and_return true
      get :index, company_id: company
      expect(assigns(:power_of_attorneys)).to eq([power_of_attorney])
      expect(response).to be_success
    end

    it "blocks unauthorized user" do
      expect(user).to receive(:view_power_of_attorneys?).and_return false
      get :index, company_id: company
      expect(response).to redirect_to(company_path(company))
    end
  end

  describe "GET new" do
    it "assigns a new power_of_attorney" do
      expect(user).to receive(:edit_power_of_attorneys?).and_return true
      get :new, company_id: company
      expect(assigns(:power_of_attorney)).to be_a_new(PowerOfAttorney)
      expect(response).to be_success
    end

    it "block unauthorized user" do
      expect(user).to receive(:edit_power_of_attorneys?).and_return false
      get :new, company_id: company
      expect(response).to redirect_to(company_path(company))
    end
  end

  describe "POST create" do

    describe "with valid params" do
      it "creates a new PowerOfAttorney" do
        expect(user).to receive(:edit_power_of_attorneys?).and_return true
        expect do
          post :create, company_id: power_of_attorney.company, power_of_attorney: {start_date: power_of_attorney.start_date,
                                                                                   expiration_date: power_of_attorney.expiration_date,
                                                                                   company_id: power_of_attorney.company.id,
                                                                                   attachment: fixture_file_upload('/files/attorney.png', 'image/png'),
                                                                                   attachment_file_name: "SampleAttachment.png"}
        end.to change(PowerOfAttorney, :count).by(1)
      end

      it "assigns a newly created power_of_attorney as @power_of_attorney" do
        expect(user).to receive(:edit_power_of_attorneys?).and_return true
        post :create, company_id: power_of_attorney.company, power_of_attorney: {start_date: power_of_attorney.start_date,
                                                                                 expiration_date: power_of_attorney.expiration_date,
                                                                                 company_id: power_of_attorney.company.id,
                                                                                 attachment: fixture_file_upload('/files/attorney.png', 'image/png'),
                                                                                 attachment_file_name: "SampleAttachment.png"}
        expect(assigns(:power_of_attorney)).to be_a(PowerOfAttorney)
        expect(assigns(:power_of_attorney)).to be_persisted
      end

      it "redirects to the created power_of_attorney" do
        expect(user).to receive(:edit_power_of_attorneys?).and_return true
        post :create, company_id: power_of_attorney.company.id, power_of_attorney: {start_date: power_of_attorney.start_date,
                                                                                    expiration_date: power_of_attorney.expiration_date,
                                                                                    company_id: power_of_attorney.company.id,
                                                                                    attachment: fixture_file_upload('/files/attorney.png', 'image/png'),
                                                                                    attachment_file_name: "SampleAttachment.png"}
        expect(response).to redirect_to(action: 'index')
      end
    end

    it "blocks unauthorized user" do
      expect(user).to receive(:edit_power_of_attorneys?).and_return false
      expect do
          post :create, company_id: power_of_attorney.company, power_of_attorney: {start_date: power_of_attorney.start_date,
                                                                                   expiration_date: power_of_attorney.expiration_date,
                                                                                   company_id: power_of_attorney.company.id,
                                                                                   attachment: fixture_file_upload('/files/attorney.png', 'image/png'),
                                                                                   attachment_file_name: "SampleAttachment.png"}
      end.not_to change(PowerOfAttorney, :count)

      expect(response).to redirect_to company_path(company)
    end

    describe "with invalid params" do
      it "re-renders the 'new' template" do
        expect(user).to receive(:edit_power_of_attorneys?).and_return true
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(PowerOfAttorney).to receive(:save).and_return(false)
        post :create, company_id: company.id, power_of_attorney: {name: 'This is bad.'}
        expect(response).to render_template("new")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested power_of_attorney" do
      expect(user).to receive(:edit_power_of_attorneys?).and_return true
      delete :destroy, id: power_of_attorney.id, company_id: power_of_attorney.company.id
      expect(PowerOfAttorney.count).to eq(0)
    end

    it "redirects to the power_of_attorneys list" do
      expect(user).to receive(:edit_power_of_attorneys?).and_return true
      c = power_of_attorney.company
      delete :destroy, id: power_of_attorney.id, company_id: power_of_attorney.company.id
      expect(response).to redirect_to(company_power_of_attorneys_path(c))
    end

    it "blocks unauthorized user" do
      expect(user).to receive(:edit_power_of_attorneys?).and_return false
      delete :destroy, id: power_of_attorney.id, company_id: power_of_attorney.company.id
      expect(PowerOfAttorney.count).to eq(1)
      expect(response).to redirect_to(company_path(company))
    end
  end

  describe "download" do
    let(:attachment_data) { instance_double "attachment data" }
    let(:controller) { @controller } # rubocop:disable RSpec/InstanceVariable

    before do
      allow_any_instance_of(PowerOfAttorney).to receive(:attachment_data).and_return attachment_data
      allow_any_instance_of(PowerOfAttorney).to receive(:attachment_file_name).and_return "file_name"
      allow_any_instance_of(PowerOfAttorney).to receive(:attachment_content_type).and_return "content_type"
    end

    it "sends POA data" do
      expect(user).to receive(:view_power_of_attorneys?).and_return true
      expect(controller).to receive(:send_data) do |data, options|
        expect(data).to eq attachment_data
        expect(options).to eq(filename: "file_name", type: "content_type", disposition: "attachment")

        # Need this so the controller knows some template was utilized (since we mocked
        # away the send_data call)
        controller.render nothing: true
      end
      get :download, company_id: power_of_attorney.company_id, id: power_of_attorney.id
    end

    it "returns error message if POA not found" do
      power_of_attorney.destroy
      expect(user).to receive(:view_power_of_attorneys?).and_return true
      expect(controller).not_to receive(:send_data)
      get :download, company_id: power_of_attorney.company_id, id: power_of_attorney.id
      expect(response).to redirect_to(companies_path)
    end

    it "blocks unauthorized user" do
      expect(user).to receive(:view_power_of_attorneys?).and_return false
      expect(controller).not_to receive(:send_data)
      get :download, company_id: power_of_attorney.company_id, id: power_of_attorney.id
      expect(response).to redirect_to(companies_path)
    end
  end

end
