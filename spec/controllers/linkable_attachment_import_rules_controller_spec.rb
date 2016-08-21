require 'spec_helper'

describe LinkableAttachmentImportRulesController do
  before(:each) do

    @rule = Factory(:linkable_attachment_import_rule)
    @admin_user = Factory(:user,:admin=>true)
  end
  describe 'security' do
    context 'admins' do
      before(:each) do
        sign_in_as @admin_user
      end
      it 'should allow index' do
        get :index
        expect(response).to be_success
      end
      it 'should redirect show' do 
        get :show, :id=>@rule.id
        expect(response).to redirect_to "/linkable_attachment_import_rules/#{@rule.id}/edit"
      end
      it 'should allow new' do
        get :new
        expect(response).to be_success
      end
      it 'should allow edit' do
        get :edit, :id=>@rule.id
        expect(response).to be_success
      end
      it 'should allow delete' do
        delete :destroy, :id=>@rule.id
        expect(response).not_to be_an_admin_redirect
      end
      it 'should allow update' do
        post :update, :id=>@rule.id
        expect(response).not_to be_an_admin_redirect
      end
      it 'should allow create' do
        put :create, :linkable_attachment_import_rule => {:model_field_uid=>'ord_ord_num', :path=>'/some/path'}
        expect(response).not_to be_an_admin_redirect
      end
    end
    context 'non-admins' do
      before(:each) do
        @base_user = Factory(:user)
        sign_in_as @base_user
      end
      it "shouldn't allow index" do
        get :index
        expect(response).to be_an_admin_redirect
      end
      it "shouldn't allow new" do
        get :new
        expect(response).to be_an_admin_redirect
      end 
      it "shouldn't allow edit" do
        get :edit, :id=>1
        expect(response).to be_an_admin_redirect
      end
      it "shouldn't allow delete" do
        delete :destroy, :id=>@rule.id
        expect(response).to be_an_admin_redirect
        expect(LinkableAttachmentImportRule.where(:id=>@rule.id).size).to eq(1)
      end
      it "shouldn't allow update" do
        post :update, :id=>@rule.id, :model_field_uid=>'something'
        expect(response).to be_an_admin_redirect
        expect(LinkableAttachmentImportRule.find(@rule.id).model_field_uid).not_to eq('something')
      end
      it "shouldn't allow create" do
        put :create, :model_field_uid=>'prod_uid', :path=>'/path/to'
        expect(response).to be_an_admin_redirect
        expect(LinkableAttachmentImportRule.all.size).to eq(1)
      end
    end
  end
  describe 'normal actions' do
    before(:each) do
      sign_in_as @admin_user
    end
    it 'should set @rule for edit' do
      get :edit, :id=>@rule.id
      expect(assigns(:rule)).to eq(@rule)
    end
    it 'should set @rule for new' do
      get :new
      expect(assigns(:rule)).to be_a LinkableAttachmentImportRule
      expect(assigns(:rule).id).to be_nil
    end
    it 'should delete rule' do
      delete :destroy, :id=>@rule.id
      expect(flash[:notices].first).to eq("Rule deleted successfully.")
      expect(LinkableAttachmentImportRule.all).to be_empty
    end
    it 'should update rule' do
      post :update, :id=>@rule.id, :linkable_attachment_import_rule => {:model_field_uid=>'ord_ord_num', :path=>'/some/path'}
      expect(flash[:notices].first).to eq("Rule updated successfully.")
      @rule.reload
      expect(@rule.model_field_uid).to eq('ord_ord_num')
      expect(@rule.path).to eq('/some/path')
    end
    it 'should create rule' do
      put :create, :linkable_attachment_import_rule => {:model_field_uid=>'ord_ord_num', :path=>'/some/path'}
      expect(flash[:notices].first).to eq("Rule created successfully.")
      r = LinkableAttachmentImportRule.all
      expect(r.size).to eq(2) #the one in the test setup and the one that was created
      expect(r.last.model_field_uid).to eq('ord_ord_num')
      expect(r.last.path).to eq('/some/path')
    end
  end
end
