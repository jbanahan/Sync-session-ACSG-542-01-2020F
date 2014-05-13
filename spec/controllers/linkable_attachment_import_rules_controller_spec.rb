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
        response.should be_success
      end
      it 'should redirect show' do 
        get :show, :id=>@rule.id
        response.should redirect_to "/linkable_attachment_import_rules/#{@rule.id}/edit"
      end
      it 'should allow new' do
        get :new
        response.should be_success
      end
      it 'should allow edit' do
        get :edit, :id=>@rule.id
        response.should be_success
      end
      it 'should allow delete' do
        delete :destroy, :id=>@rule.id
        response.should_not be_an_admin_redirect
      end
      it 'should allow update' do
        post :update, :id=>@rule.id
        response.should_not be_an_admin_redirect
      end
      it 'should allow create' do
        put :create, :linkable_attachment_import_rule => {:model_field_uid=>'ord_ord_num', :path=>'/some/path'}
        response.should_not be_an_admin_redirect
      end
    end
    context 'non-admins' do
      before(:each) do
        @base_user = Factory(:user)
        sign_in_as @base_user
      end
      it "shouldn't allow index" do
        get :index
        response.should be_an_admin_redirect
      end
      it "shouldn't allow new" do
        get :new
        response.should be_an_admin_redirect
      end 
      it "shouldn't allow edit" do
        get :edit, :id=>1
        response.should be_an_admin_redirect
      end
      it "shouldn't allow delete" do
        delete :destroy, :id=>@rule.id
        response.should be_an_admin_redirect
        LinkableAttachmentImportRule.where(:id=>@rule.id).should have(1).rule
      end
      it "shouldn't allow update" do
        post :update, :id=>@rule.id, :model_field_uid=>'something'
        response.should be_an_admin_redirect
        LinkableAttachmentImportRule.find(@rule.id).model_field_uid.should_not == 'something'
      end
      it "shouldn't allow create" do
        put :create, :model_field_uid=>'prod_uid', :path=>'/path/to'
        response.should be_an_admin_redirect
        LinkableAttachmentImportRule.all.should have(1).rule
      end
    end
  end
  describe 'normal actions' do
    before(:each) do
      sign_in_as @admin_user
    end
    it 'should set @rule for edit' do
      get :edit, :id=>@rule.id
      assigns(:rule).should == @rule
    end
    it 'should set @rule for new' do
      get :new
      assigns(:rule).should be_a LinkableAttachmentImportRule
      assigns(:rule).id.should be_nil
    end
    it 'should delete rule' do
      delete :destroy, :id=>@rule.id
      flash[:notices].first.should == "Rule deleted successfully."
      LinkableAttachmentImportRule.all.should be_empty
    end
    it 'should update rule' do
      post :update, :id=>@rule.id, :linkable_attachment_import_rule => {:model_field_uid=>'ord_ord_num', :path=>'/some/path'}
      flash[:notices].first.should == "Rule updated successfully."
      @rule.reload
      @rule.model_field_uid.should == 'ord_ord_num'
      @rule.path.should == '/some/path'
    end
    it 'should create rule' do
      put :create, :linkable_attachment_import_rule => {:model_field_uid=>'ord_ord_num', :path=>'/some/path'}
      flash[:notices].first.should == "Rule created successfully."
      r = LinkableAttachmentImportRule.all
      r.should have(2).rules #the one in the test setup and the one that was created
      r.last.model_field_uid.should == 'ord_ord_num'
      r.last.path.should == '/some/path'
    end
  end
end
