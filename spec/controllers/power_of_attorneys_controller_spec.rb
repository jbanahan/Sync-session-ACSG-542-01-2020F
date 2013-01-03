require 'spec_helper'
describe PowerOfAttorneysController do
  before(:each) do
    activate_authlogic
    @company = Factory(:company)
    @user = Factory(:user, :company => @company)
    @poa = Factory(:power_of_attorney, :user => @user, :company => @company)
  end

  describe "GET index" do
    it "assigns all power_of_attorneys as @poa" do
      get :index, :company_id => @company
      assigns(:power_of_attorneys).should eq([@poa])
      response.should be_success
    end
  end

  describe "GET new" do
    it "assigns a new power_of_attorney" do
      get :new, :company_id => @company
      assigns(:power_of_attorney).should be_a_new(PowerOfAttorney)
      response.should be_success
    end
  end

  describe "POST create" do
    before(:each) do
      UserSession.create @user
    end
    
    describe "with valid params" do
      it "creates a new PowerOfAttorney" do
        expect {
          post :create, :company_id => @poa.company, :power_of_attorney => {:start_date => @poa.start_date,
            :expiration_date => @poa.expiration_date,
            :company_id => @poa.company.id,
            :attachment => '/tmp/sample_attachment.jpg',
            :attachment_file_name => "SampleAttachment.jpg"}
        }.to change(PowerOfAttorney, :count).by(1)
      end

      it "assigns a newly created power_of_attorney as @power_of_attorney" do
        post :create, :company_id => @poa.company, :power_of_attorney => {:start_date => @poa.start_date,
          :expiration_date => @poa.expiration_date,
          :company_id => @poa.company.id,
          :attachment => '/tmp/sample_attachment.jpg',
          :attachment_file_name => "SampleAttachment.jpg"}
        assigns(:power_of_attorney).should be_a(PowerOfAttorney)
        assigns(:power_of_attorney).should be_persisted
      end

      it "redirects to the created power_of_attorney" do
        post :create, :company_id => @poa.company.id, :power_of_attorney => {:start_date => @poa.start_date,
          :expiration_date => @poa.expiration_date,
          :company_id => @poa.company.id,
          :attachment => '/tmp/sample_attachment.jpg',
          :attachment_file_name => "SampleAttachment.jpg"}
        response.should redirect_to(:action => 'index')
      end
    end

    describe "with invalid params" do
      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        PowerOfAttorney.any_instance.stub(:save).and_return(false)
        post :create, :company_id => @company.id, :power_of_attorney => {}
        response.should render_template("new")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested power_of_attorney" do
      delete :destroy, :id => @poa.id, :company_id => @poa.company.id
      PowerOfAttorney.count.should == 0
    end

    it "redirects to the power_of_attorneys list" do
      c = @poa.company
      delete :destroy, :id => @poa.id, :company_id => @poa.company.id
      response.should redirect_to(company_power_of_attorneys_path(c))
    end
  end

end
