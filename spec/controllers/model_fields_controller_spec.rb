describe ModelFieldsController do
  it "should filter fields w/o permission" do
    u = Factory(:user)

    sign_in_as u
    get :find_by_module_type, :module_type=>"Entry"
    r = JSON.parse response.body
    found_uids = r.collect {|mf| mf["uid"]}
    expect(found_uids).not_to include("ent_broker_invoice_total")
  end
  it "should include fields w permission" do
    MasterSetup.get.update_attributes(:broker_invoice_enabled=>true)
    u = Factory(:user,:company=>Factory(:company,:master=>true),:broker_invoice_view=>true)

    sign_in_as u
    get :find_by_module_type, :module_type=>"Entry"
    r = JSON.parse response.body
    found_uids = r.collect {|mf| mf["uid"]}
    expect(found_uids).to include("ent_broker_invoice_total")
  end

  describe "glossary" do
    render_views

    before :each do
      @mf = ModelField.new(10000,:test,CoreModule::PRODUCT,:name)
    end

    it "should return product model fields with the proper label" do
      u = Factory(:user)
      sign_in_as u

      get :glossary, {core_module: 'Product'}
      expect(response).to be_success
      expect(assigns(:fields).length).to be > 0
      expect(assigns(:label)).to eq("Product")
    end

    it "should redirect when the module is not found" do
      u = Factory(:user)
      sign_in_as u

      get :glossary, {core_module: 'nonexistent'}
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq("Module nonexistent was not found.")
    end

    it "should redirect for users who aren't logged in" do
      get :glossary, {core_module: 'doesnt_matter'}
      expect(response.status).to eq(302)
    end
  end
end
