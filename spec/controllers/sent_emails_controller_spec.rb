describe SentEmailsController do

  let(:user) { create(:admin_user, :company => create(:company, :master=>true)) }
  let(:email) { create(:sent_email, email_body: "content") }

  before :each do
    sign_in_as user
  end

  describe "GET 'index'" do
    it "should be successful" do
      get :index
      expect(response).to be_success
      expect(assigns(:default_display)).to start_with("By default")
    end

    it "executes a search" do
      get :index, {s1: "2017-01-01", f1: "email_date", c1: "sw"}
      expect(response).to be_success
      expect(assigns(:default_display)).to be_nil
    end

    it "should reject if user isn't admin" do
      user.admin = false
      user.save!

      get :index
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end

  describe "GET 'show'" do
    it "shows an email" do
      get :show, :id => email.id
      expect(response).to be_success
      expect(assigns(:sent_email)).to eq email
    end

    it "rejects if user isn't admin" do
      user.admin = false
      user.save!

      get :show, :id=> email.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end

  describe "body" do
    it "returns a sent email's body" do
      get :body, id: email.id
      expect(response).to be_success
      expect(response.body).to eq email.email_body
    end

    it "rejects if user is not an admin" do
      user.admin = false
      user.save!

      get :body, id: email.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq 1
    end
  end
end
