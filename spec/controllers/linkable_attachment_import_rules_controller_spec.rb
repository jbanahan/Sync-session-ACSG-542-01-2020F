describe LinkableAttachmentImportRulesController do
  let!(:rule) { FactoryBot(:linkable_attachment_import_rule) }
  let(:admin_user) { FactoryBot(:user, admin: true) }

  describe 'security' do
    context 'admins' do
      before do
        sign_in_as admin_user
      end

      it 'allows index' do
        get :index
        expect(response).to be_success
      end

      it 'redirects show' do
        get :show, id: rule.id
        expect(response).to redirect_to "/linkable_attachment_import_rules/#{rule.id}/edit"
      end

      it 'allows new' do
        get :new
        expect(response).to be_success
      end

      it 'allows edit' do
        get :edit, id: rule.id
        expect(response).to be_success
      end

      it 'allows delete' do
        delete :destroy, id: rule.id
        expect(response).not_to be_an_admin_redirect
      end

      it 'allows update' do
        post :update, id: rule.id, linkable_attachment_import_rule: {path: 'path'}
        expect(response).not_to be_an_admin_redirect
      end

      it 'allows create' do
        put :create, linkable_attachment_import_rule: {model_field_uid: 'ord_ord_num', path: '/some/path'}
        expect(response).not_to be_an_admin_redirect
      end
    end

    context 'non-admins' do
      let(:base_user) { FactoryBot(:user) }

      before do
        sign_in_as base_user
      end

      it "does not allow index" do
        get :index
        expect(response).to be_an_admin_redirect
      end

      it "does not allow new" do
        get :new
        expect(response).to be_an_admin_redirect
      end

      it "does not allow edit" do
        get :edit, id: 1
        expect(response).to be_an_admin_redirect
      end

      it "does not allow delete" do
        delete :destroy, id: rule.id
        expect(response).to be_an_admin_redirect
        expect(LinkableAttachmentImportRule.where(id: rule.id).size).to eq(1)
      end

      it "does not allow update" do
        post :update, id: rule.id, model_field_uid: 'something'
        expect(response).to be_an_admin_redirect
        expect(LinkableAttachmentImportRule.find(rule.id).model_field_uid).not_to eq('something')
      end

      it "does not allow create" do
        put :create, model_field_uid: 'prod_uid', path: '/path/to'
        expect(response).to be_an_admin_redirect
        expect(LinkableAttachmentImportRule.all.size).to eq(1)
      end
    end
  end

  describe 'normal actions' do
    before do
      sign_in_as admin_user
    end

    it 'sets rule for edit' do
      get :edit, id: rule.id
      expect(assigns(:rule)).to eq(rule)
    end

    it 'sets rule for new' do
      get :new
      expect(assigns(:rule)).to be_a LinkableAttachmentImportRule
      expect(assigns(:rule).id).to be_nil
    end

    it 'deletes rule' do
      delete :destroy, id: rule.id
      expect(flash[:notices].first).to eq("Rule deleted successfully.")
      expect(LinkableAttachmentImportRule.all).to be_empty
    end

    it 'updates rule' do
      post :update, id: rule.id, linkable_attachment_import_rule: {model_field_uid: 'ord_ord_num', path: '/some/path'}
      expect(flash[:notices].first).to eq("Rule updated successfully.")
      rule.reload
      expect(rule.model_field_uid).to eq('ord_ord_num')
      expect(rule.path).to eq('/some/path')
    end

    it 'creates rule' do
      put :create, linkable_attachment_import_rule: {model_field_uid: 'ord_ord_num', path: '/some/path'}
      expect(flash[:notices].first).to eq("Rule created successfully.")
      r = LinkableAttachmentImportRule.all
      expect(r.size).to eq(2) # the one in the test setup and the one that was created
      expect(r.last.model_field_uid).to eq('ord_ord_num')
      expect(r.last.path).to eq('/some/path')
    end
  end
end
