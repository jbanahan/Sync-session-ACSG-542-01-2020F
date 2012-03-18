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
    it "should reject if survey is locked" do
      Survey.any_instance.stub(:can_edit?).and_return(true)
      Survey.any_instance.should_receive(:locked?).and_return(true)
      get :edit, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should reject if user cannot edit" do
      Survey.any_instance.stub(:can_edit?).and_return(false)
      get :edit, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should pass if user has edit_survey permission" do
      Survey.any_instance.stub(:can_edit?).and_return(true)
      Survey.any_instance.stub(:locked?).and_return(false)
      get :edit, :id=>@s.id
      assigns(:survey).should == @s
    end
  end
  describe "update" do
    before :each do
      @s = Factory(:survey,:company_id=>@u.company_id)
    end
    it "should reject is survey is locked" do
      Survey.any_instance.stub(:can_edit?).and_return(true)
      Survey.any_instance.should_receive(:locked?).and_return(true)
      post :update, :id=>@s.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should reject if user cannot edit" do
      Survey.any_instance.stub(:can_edit?).and_return(false)
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
    it "should reject if survey is locked" do
      Survey.any_instance.should_receive(:locked?).and_return(true)
      delete :destroy, :id=>@s.id 
      response.should be_redirect
      flash[:errors].should have(1).message
      Survey.find(@s.id).should == @s #not deleted
    end
    it "should reject if user cannot edit" do
      Survey.any_instance.stub(:can_edit?).and_return(false)
      delete :destroy, :id=>@s.id 
      response.should be_redirect
      flash[:errors].should have(1).message
      Survey.find(@s.id).should == @s #not deleted
    end
    it "should pass if user can edit" do
      Survey.any_instance.stub(:can_edit?).and_return(true)
      delete :destroy, :id=>@s.id 
      response.should redirect_to surveys_path
      flash[:notices].first.should == "Survey deleted successfully."
      Survey.count.should == 0
    end
  end
  describe "show_assign" do
    before :each do
      @s = Factory(:survey,:company_id=>@u.company_id)
    end
    it "should show assignment page if user can edit survey" do
      Survey.any_instance.stub(:can_edit?).and_return(true)
      get :show_assign, :id=>@s.id
      response.should be_success
      assigns(:survey).should == @s
    end
    it "should not show assignment if user cannot edit survey" do
      Survey.any_instance.stub(:can_edit?).and_return(false)
      get :show_assign, :id=>@s.id
      response.should redirect_to request.referrer
      flash[:errors].should have(1).error
    end
  end
  describe "assign" do
    before :each do 
      @s = Factory(:survey)
    end
    it "should assign if user can edit survey" do
      u2 = Factory(:user)
      u3 = Factory(:user)
      Survey.any_instance.stub(:can_edit?).and_return(true)
      post :assign, :id=>@s.id, :assign=>{"0"=>u2.id.to_s,"1"=>u3.id.to_s}
      response.should redirect_to survey_path(@s)
      flash[:notices].should have(1).message
      SurveyResponse.find_by_survey_id_and_user_id(@s.id,u2.id).should_not be_nil
      SurveyResponse.find_by_survey_id_and_user_id(@s.id,u3.id).should_not be_nil
    end
    it "should not assign if user cannot edit survey" do
      u2 = Factory(:user)
      Survey.any_instance.stub(:can_edit?).and_return(false)
      post :assign, :id=>@s.id, :assign=>{"0"=>u2.id.to_s}
      response.should redirect_to request.referrer
      flash[:errors].should have(1).item
    end
    it "should not assign to the same user twice" do
      u2 = Factory(:user)
      Factory(:survey_response,:survey=>@s,:user=>u2) #making this one exist already
      u3 = Factory(:user) #this user should still have one created
      Survey.any_instance.stub(:can_edit?).and_return(true)
      post :assign, :id=>@s.id, :assign=>{"0"=>u2.id.to_s,"1"=>u3.id.to_s}
      response.should redirect_to survey_path(@s)
      flash[:notices].should have(2).messages
      SurveyResponse.find_by_survey_id_and_user_id(@s.id,u3.id).should_not be_nil
      SurveyResponse.where(:user_id=>u2.id,:survey_id=>@s.id).count.should == 1
    end
  end
end
