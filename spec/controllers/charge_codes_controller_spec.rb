describe ChargeCodesController do
  before :each do
    @u = Factory(:user,:admin=>true,:company=>Factory(:company,:master=>true))

    sign_in_as @u
  end
  describe "index" do
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should show all charge codes" do
      3.times {|i| ChargeCode.create!(:code=>"#{5-i}")}
      get :index
      c = assigns[:charge_codes]
      expect(c.size).to eq(3)
      expect(c.first.code).to eq("3")
    end
  end

  describe "create" do
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      post :create, {'charge_code'=> {'code'=>"x",'description'=>"y"} }
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      expect(ChargeCode.all).to be_empty
    end
    it "should create charge code" do
      post :create, {'charge_code'=> {'code'=>"x",'description'=>"y"} }
      expect(response).to redirect_to charge_codes_path
      c = ChargeCode.first
      expect(c.code).to eq("x")
      expect(c.description).to eq("y")
    end
  end

  describe "destroy" do
    before :each do
      @c = ChargeCode.create!(:code=>"a")
    end
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      delete :destroy, :id=>@c.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should destroy charge code" do
      delete :destroy, :id=>@c.id
      expect(response).to be_redirect
      expect(flash[:notices].size).to eq(1)
      expect(ChargeCode.all).to be_empty
    end
  end

  describe "update" do
    before :each do
      @c = ChargeCode.create!(:code=>"a")
    end
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      put :update, { :id=>@c.id, 'charge_code'=>{'code'=>'b','description'=>'xyz'} }
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      expect(ChargeCode.find(@c.id).code).to eq("a")
    end
    it "should update charge code" do
      put :update, { :id=>@c.id, 'charge_code'=>{'code'=>'b','description'=>'xyz'} }
      expect(response).to be_redirect
      expect(flash[:notices].size).to eq(1)
      expect(ChargeCode.find(@c.id).code).to eq("b")
    end
  end

end
