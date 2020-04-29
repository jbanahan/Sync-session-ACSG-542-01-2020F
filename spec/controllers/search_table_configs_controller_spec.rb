describe SearchTableConfigsController do
  let!(:user) { Factory(:sys_admin_user, company: Factory(:company, name: "Oracle")) }
  before { sign_in_as user }

  describe "index" do
    let!(:stc) { Factory(:search_table_config) }

    it "renders for sys-admin user" do
      get :index
      expect(assigns(:configs)).to eq [stc]
      expect(response).to render_template :index
    end

    it "doesn't allow use by non-sys-admin" do
      expect(user).to receive(:sys_admin?).and_return false
      get :index
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
    end
  end

  describe "new" do
    let!(:stc) { Factory(:search_table_config) }
    let!(:co_1) { user.company }
    let!(:co_2) { Factory(:company, name: "Microsoft") }
    let!(:co_3) { Factory(:company, name: "Google") }

    it "renders for sys-admin user" do
      get :new
      expect(assigns(:config)).to be_instance_of SearchTableConfig
      expect(assigns(:companies)).to eq [co_3, co_2, co_1]
      expect(response).to render_template :new_edit
    end

    it "doesn't allow use by non-sys-admin" do
      expect(user).to receive(:sys_admin?).and_return false
      get :new
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
    end
  end

  describe "edit" do
    let!(:stc) { Factory(:search_table_config) }
    let!(:co_1) { user.company }
    let!(:co_2) { Factory(:company, name: "Microsoft") }
    let!(:co_3) { Factory(:company, name: "Google") }


    it "renders for sys-admin user" do
      get :edit, id: stc.id
      expect(assigns(:config)).to eq stc
      expect(assigns(:companies)).to eq [co_3, co_2, co_1]
      expect(response).to render_template :new_edit
    end

    it "doesn't allow use by non-sys-admin" do
      expect(user).to receive(:sys_admin?).and_return false
      get :edit, id: stc.id
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
    end
  end

  describe "create" do
    let!(:co) { Factory(:company, name: "Oracle") }

    it "creates stc for sys-admin" do
      json = '{"columns: [], "criteria": [], "sorts": []}'
      post :create, search_table_config: {page_uid: "page_uid", name: "name", config_json: json, company_id: co.id}
      stc = SearchTableConfig.first
      expect(stc.page_uid).to eq "page_uid"
      expect(stc.name).to eq "name"
      expect(stc.config_json).to eq json
      expect(stc.company).to eq co
      expect(response).to redirect_to search_table_configs_path
    end

    it "doesn't allow use by non-sys-admin" do
      expect(user).to receive(:sys_admin?).and_return false
      json = '{"columns: [], "criteria": [], "sorts": []}'
      post :create, search_table_config: {page_uid: "page_uid", name: "name", config_json: json}
      expect(SearchTableConfig.first).to be_nil
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
    end
  end

  describe "update" do
    let!(:co_1) { Factory(:company, name: "Oracle") }
    let!(:co_2) { Factory(:company, name: "Microsoft") }
    let!(:original_json) { '{"columns: [], "criteria": [], "sorts": []}' }
    let!(:stc) { Factory(:search_table_config, company: co_1, page_uid: "original page_uid", name: "original name", config_json: original_json) }

    it "updates stc for sys-admin" do
      new_json = '{"columns: ["prodven_puid"], "criteria": [], "sorts": []}'
      put :update, id: stc.id, search_table_config: {company_id: co_2.id, page_uid: "new page_uid", name: "new name", config_json: new_json}
      stc.reload
      expect(stc.company).to eq co_2
      expect(stc.page_uid).to eq "new page_uid"
      expect(stc.name).to eq "new name"
      expect(stc.config_json).to eq new_json
      expect(response).to redirect_to search_table_configs_path
    end

    it "doesn't allow use by non-sys-admin" do
      expect(user).to receive(:sys_admin?).and_return false
      new_json = '{"columns: ["prodven_puid"], "criteria": [], "sorts": []}'
      put :update, id: stc.id, search_table_config: {company_id: co_2.id, page_uid: "new page_uid", name: "new name", config_json: new_json}
      stc.reload
      expect(stc.company).to eq co_1
      expect(stc.page_uid).to eq "original page_uid"
      expect(stc.name).to eq "original name"
      expect(stc.config_json).to eq original_json
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
    end
  end

  describe "destroy" do
    let!(:stc) { Factory(:search_table_config) }

    it "deletes stc for sys-admin" do
      delete :destroy, id: stc.id
      expect(SearchTableConfig.count).to eq 0
      expect(response).to redirect_to search_table_configs_path
    end

    it "doesn't allow use by non-sys-admin" do
      expect(user).to receive(:sys_admin?).and_return false
      delete :destroy, id: stc.id
      expect(SearchTableConfig.count).to eq 1
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include "Only system admins can do this."
    end
  end
end
