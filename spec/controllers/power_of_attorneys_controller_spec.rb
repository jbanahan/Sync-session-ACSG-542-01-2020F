require 'spec_helper'
describe PowerOfAttorneysController do
  before(:each) do
    @company = Factory(:company)
    @user = Factory(:user, :company => @company)
    @poa = Factory(:power_of_attorney, :user => @user, :company => @company)
    sign_in_as @user
  end

  describe "GET index" do
    it "assigns all power_of_attorneys as @poa" do
      get :index, :company_id => @company
      expect(assigns(:power_of_attorneys)).to eq([@poa])
      expect(response).to be_success
    end
  end

  describe "GET new" do
    it "assigns a new power_of_attorney" do
      get :new, :company_id => @company
      expect(assigns(:power_of_attorney)).to be_a_new(PowerOfAttorney)
      expect(response).to be_success
    end
  end

  describe "POST create" do
    
    describe "with valid params" do
      it "creates a new PowerOfAttorney" do
        expect {
          post :create, :company_id => @poa.company, :power_of_attorney => {:start_date => @poa.start_date,
            :expiration_date => @poa.expiration_date,
            :company_id => @poa.company.id,
            :attachment => fixture_file_upload('/files/attorney.png', 'image/png'),
            :attachment_file_name => "SampleAttachment.png"}
        }.to change(PowerOfAttorney, :count).by(1)
      end

      it "assigns a newly created power_of_attorney as @power_of_attorney" do
        post :create, :company_id => @poa.company, :power_of_attorney => {:start_date => @poa.start_date,
          :expiration_date => @poa.expiration_date,
          :company_id => @poa.company.id,
          :attachment => fixture_file_upload('/files/attorney.png', 'image/png'),
          :attachment_file_name => "SampleAttachment.png"}
        expect(assigns(:power_of_attorney)).to be_a(PowerOfAttorney)
        expect(assigns(:power_of_attorney)).to be_persisted
      end

      it "redirects to the created power_of_attorney" do
        post :create, :company_id => @poa.company.id, :power_of_attorney => {:start_date => @poa.start_date,
          :expiration_date => @poa.expiration_date,
          :company_id => @poa.company.id,
          :attachment => fixture_file_upload('/files/attorney.png', 'image/png'),
          :attachment_file_name => "SampleAttachment.png"}
        expect(response).to redirect_to(:action => 'index')
      end
    end

    describe "with invalid params" do
      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(PowerOfAttorney).to receive(:save).and_return(false)
        post :create, :company_id => @company.id, :power_of_attorney => {}
        expect(response).to render_template("new")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested power_of_attorney" do
      delete :destroy, :id => @poa.id, :company_id => @poa.company.id
      expect(PowerOfAttorney.count).to eq(0)
    end

    it "redirects to the power_of_attorneys list" do
      c = @poa.company
      delete :destroy, :id => @poa.id, :company_id => @poa.company.id
      expect(response).to redirect_to(company_power_of_attorneys_path(c))
    end
  end

end
