describe ChargeCodesController do
  let(:user) { create(:user, admin: true, company: create(:company, master: true)) }

  before do
    sign_in_as user
  end

  describe "index" do
    it "onlies allow admins" do
      user.admin = false
      user.save!
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "shows all charge codes" do
      3.times {|i| ChargeCode.create!(code: (5 - i).to_s)}
      get :index
      c = assigns[:charge_codes]
      expect(c.size).to eq(3)
      expect(c.first.code).to eq("3")
    end
  end

  describe "create" do
    it "onlies allow admins" do
      user.admin = false
      user.save!
      post :create, {'charge_code' => {'code' => "x", 'description' => "y"} }
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      expect(ChargeCode.all).to be_empty
    end

    it "creates charge code" do
      post :create, {'charge_code' => {'code' => "x", 'description' => "y"} }
      expect(response).to redirect_to charge_codes_path
      c = ChargeCode.first
      expect(c.code).to eq("x")
      expect(c.description).to eq("y")
    end
  end

  describe "destroy" do
    let(:charge_code) { ChargeCode.create!(code: "a") }

    it "only allows admins" do
      user.admin = false
      user.save!
      delete :destroy, id: charge_code.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "destroys charge code" do
      delete :destroy, id: charge_code.id
      expect(response).to be_redirect
      expect(flash[:notices].size).to eq(1)
      expect(ChargeCode.all).to be_empty
    end
  end

  describe "update" do
    let(:charge_code) { ChargeCode.create!(code: "a") }

    it "only allows admins" do
      user.admin = false
      user.save!
      put :update, params: { :id => charge_code.id, 'charge_code' => {'code' => 'b', 'description' => 'xyz'} }
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      expect(ChargeCode.find(charge_code.id).code).to eq("a")
    end

    it "updates charge code" do
      put :update, params: { :id => charge_code.id, 'charge_code' => {'code' => 'b', 'description' => 'xyz'} }
      expect(response).to be_redirect
      expect(flash[:notices].size).to eq(1)
      expect(ChargeCode.find(charge_code.id).code).to eq("b")
    end
  end
end
