describe ChargeCategoriesController do

  before :each do
    @c = create(:company)
    @cat = @c.charge_categories.create!(:charge_code=>'A', :category=>'B')

  end
  describe "index" do
    it "should require user to be admin" do
      sign_in_as create(:user)
      get :index, :company_id=>@c.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].size).to eq(1)
    end
    it "should get charge categories for given company" do
      sign_in_as create(:admin_user)
      get :index, :company_id=>@c.id
      expect(response).to be_success
      expect(assigns(:charge_categories).to_a).to eq([@cat])
    end
  end

  describe "create" do
    it "should require user to be admin" do
      sign_in_as create(:user)
      post :create, :company_id=>@c.id, 'charge_category'=>{'charge_code'=>'x', 'category'=>'y'}
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].size).to eq(1)
      @c.reload
      expect(@c.charge_categories.size).to eq(1)
    end
    it "should create category" do
      sign_in_as create(:admin_user)
      post :create, :company_id=>@c.id, 'charge_category'=>{'charge_code'=>'x', 'category'=>'y'}
      expect(response).to redirect_to company_charge_categories_path(@c)
      expect(flash[:notices].first).to eq("Charge Category created successfully.")
      @c.reload
      expect(@c.charge_categories.size).to eq(2)
      expect(@c.charge_categories.where(:charge_code=>'x').where(:category=>'y').to_a.size).to eq(1)
    end
  end

  describe "destroy" do
    it "should require user to be admin" do
      sign_in_as create(:user)
      delete :destroy, :company_id=>@c.id, :id=>@cat.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].size).to eq(1)
      @c.reload
      expect(@c.charge_categories.size).to eq(1)
    end
    it "should destroy category" do
      sign_in_as create(:admin_user)
      delete :destroy, :company_id=>@c.id, :id=>@cat.id
      expect(response).to redirect_to company_charge_categories_path(@c)
      expect(flash[:notices].first).to eq("Charge Category deleted.")
      expect(ChargeCategory.all).to be_empty
    end
  end

end
