require 'spec_helper'

describe SurveysController do
  before :each do
    activate_authlogic
    @u = Factory(:user,:survey_view=>true,:survey_edit=>true)
    UserSession.create! @u
  end
  describe 'index' do
    it "should only show surveys for logged in company" do
      to_find = Factory(:survey,:company=>@u.company)
      not_to_find = Factory(:survey)
      get :index
      assigns(:surveys).to_a.should == [to_find]
    end
    it "should reject if user does not have view_survey permission" do
      @u.update_attributes(:survey_view=>false)
      get :index
      response.should be_redirect
      flash[:errors].should have(1).message
    end
  end
  describe 'new' do
    it "should reject if user does not have edit_survey permission" do
      @u.update_attributes(:survey_edit=>false)
      get :new
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should pass if user has edit_survey permission" do
      get :new
      assigns(:survey).id.should be_nil
    end
  end
  describe "show" do
    before :each do
      @s = Factory(:survey,:company_id=>@u.company_id)
    end
    it "should fail if user doesn't have view survey permission" do
      @u.update_attributes(:survey_view=>false)
      get :show, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should fail if company_id != current_user.company_id" do
      @s.update_attributes(:company_id=>@u.company_id+1)
      get :show, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should set survey variable" do
      get :show, :id=>@s.id
      assigns(:survey).should == @s
    end
  end
  describe "edit" do
    before :each do
      @s = Factory(:survey,:company_id=>@u.company_id) 
    end
    it "should reject if user does not have edit_survey permission" do
      @u.update_attributes(:survey_edit=>false)
      get :edit, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should reject if survey is locked" do
      Survey.any_instance.should_receive(:locked?).and_return(true)
      get :edit, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should reject if survey's company does not match user's company" do
      @s.update_attributes(:company_id=>@u.company_id+1)
      get :edit, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should pass if user has edit_survey permission" do
      Survey.should_receive(:find).with(1).and_return(@s)
      @s.stub(:locked?).and_return(false)
      get :edit, :id=>1
      assigns(:survey).should == @s
    end
  end
  describe "update" do
    before :each do
      @s = Factory(:survey,:company_id=>@u.company_id)
    end
    it "should reject if user does not have edit_survey permission" do
      @u.update_attributes(:survey_edit=>false)
      post :update, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should reject is survey is locked" do
      Survey.any_instance.should_receive(:locked?).and_return(true)
      post :update, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should reject if survey company != user company" do
      @s.update_attributes(:company_id=>@u.company_id+1)
      post :update, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should pass if user has edit_survey permission" do
      post :update, {:id=>@s.id, :survey=>{:name=>'abcdef'}}
      response.should redirect_to edit_survey_path(@s)
      flash[:notices].first.should == "Survey saved."
      Survey.find(@s.id).name.should == 'abcdef'
    end
  end
  describe "create" do
    it "should reject if user does not have edit_survey permission" do
      @u.update_attributes(:survey_edit=>false)
      post :create, {:survey=>{:name=>'abc'}} 
      response.should be_redirect
      flash[:errors].should have(1).message
      Survey.count.should == 0
    end
    it "should pass if user has edit_survey permission" do
      post :create, {:survey=>{:name=>'abc'}} 
      response.should redirect_to edit_survey_path(Survey.first)
      flash[:notices].should have(1).message
      Survey.first.name.should == 'abc'
      Survey.first.company_id.should == @u.company_id
    end
    it "should set company_id based on current_user not parameter" do
      post :create, {:survey=>{:name=>'abc',:company_id => (@u.company_id+1)}} 
      response.should redirect_to edit_survey_path(Survey.first)
      flash[:notices].should have(1).message
      Survey.first.company_id.should == @u.company_id
    end
    it "should set created_by to current_user" do
      post :create, {:survey=>{:name=>'abc'}}
      Survey.first.created_by.should == @u
    end
  end
  describe "destroy" do
    before :each do
      @s = Factory(:survey,:company_id=>@u.company_id)
    end
    it "should reject if user does not have edit_survey permission" do
      @u.update_attributes(:survey_edit=>false)
      delete :destroy, :id=>@s.id 
      response.should be_redirect
      flash[:errors].should have(1).message
      Survey.find(@s.id).should == @s #not deleted
    end
    it "should reject if survey is locked" do
      Survey.any_instance.should_receive(:locked?).and_return(true)
      delete :destroy, :id=>@s.id 
      response.should be_redirect
      flash[:errors].should have(1).message
      Survey.find(@s.id).should == @s #not deleted
    end
    it "should reject if company_id != user_id" do
      @s.update_attributes(:company_id=>@u.company_id+1)
      delete :destroy, :id=>@s.id 
      response.should be_redirect
      flash[:errors].should have(1).message
      Survey.find(@s.id).should == @s #not deleted
    end
    it "should pass if user has edit_survey permission" do
      delete :destroy, :id=>@s.id 
      response.should redirect_to surveys_path
      flash[:notices].first.should == "Survey deleted successfully."
      Survey.count.should == 0
    end
  end
end
