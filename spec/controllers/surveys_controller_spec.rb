require 'spec_helper'

describe SurveysController do
  before :each do

    @u = Factory(:user,:survey_view=>true,:survey_edit=>true)
    sign_in_as @u
  end
  describe 'index' do
    it "should only show surveys for logged in company" do
      to_find = Factory(:survey,:company=>@u.company)
      archived = Factory(:survey,:company=>@u.company, archived: true)
      not_to_find = Factory(:survey)
      get :index
      expect(assigns(:surveys)).to eq [to_find]
      expect(assigns(:archived_surveys)).to be_nil
    end
    it "should reject if user does not have view_survey permission" do
      @u.update_attributes(:survey_view=>false)
      get :index
      response.should be_redirect
      flash[:errors].should have(1).message
    end

    it "shows archived surveys if prompted" do
      to_find = Factory(:survey,:company=>@u.company)
      archived = Factory(:survey,:company=>@u.company, archived: true)
      get :index, show_archived: true

      expect(assigns(:surveys)).to eq [to_find]
      expect(assigns(:archived_surveys)).to eq [archived]
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
      @s = Factory(:survey,:company_id=>@u.company_id, :name=>"Name")
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
    it "should write excel file for excel formats" do 
      wb = double
      Survey.should_receive(:find).with(@s.id.to_s).and_return(@s)
      @s.should_receive(:to_xls).and_return(wb)
      wb.should_receive(:write) do |io|
        io.string= "Test"
      end
      @controller.should_receive(:send_data) do |data, options|
        data.should == "Test"
        options[:type].should == :xls
        options[:filename].should == @s.name + ".xls"
        
        # Need this so the controller knows some template was utilized (since we mocked
        # away the send_data call)
        @controller.render :nothing => true
      end

      get :show, {:id=>@s.id, :format=>:xls}
    end
    it "should handle surveys with no names" do
      wb = double
      @s.name = ""
      Survey.should_receive(:find).with(@s.id.to_s).and_return(@s)
      @s.should_receive(:to_xls).and_return(wb)
      wb.should_receive(:write)

      @controller.should_receive(:send_data) do |data, options|
        options[:filename].should == "survey.xls"

        @controller.render :nothing => true
      end
      
      get :show, {:id=>@s.id,  :format=>:xls}
    end
    it "should enable showing archived responses" do
      get :show, {:id=>@s.id, "show_archived_responses"=>"true"}
      assigns(:show_archived).should be_true
    end

    it "should not enable showing archived responses for users with no edit privs" do
      @u.update_attributes :survey_edit => false
      get :show, {:id=>@s.id, "show_archived_responses"=>"true"}
      assigns(:show_archived).should be_false
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
      expect(response.body).to eq ({flash: {errors: ["You cannot edit a survey that has already been sent."]}, redirect: edit_survey_path(@s)}.to_json)
    end
    it "should reject if user cannot edit" do
      Survey.any_instance.stub(:can_edit?).and_return(false)
      post :update, :id=>@s.id
      expect(response.body).to eq ({flash: {errors: ["You cannot edit this survey."]}, redirect: edit_survey_path(@s)}.to_json)
    end
    it "should pass if user has edit_survey permission" do
      post :update, {:id=>@s.id, :survey=>{:name=>'abcdef'}}
      expect(response.body).to eq ({flash: {errors: nil}, redirect: edit_survey_path(@s)}.to_json)
      expect(Survey.find(@s.id).name).to eq 'abcdef'
    end
    it "should clear warnings" do
      q = @s.questions.create!(:content=>"ABC def 123",:choices=>"a\nb",:warning=>true, :require_comment => true, :require_attachment => true)
      post :update, {:id=>@s.id, :survey=>{:name=>'abcdef',:questions_attributes=>{q.id=>{:id=>q.id,:content=>"ABC def 123"}}}}
      expect(response.body).to eq ({flash: {errors: nil}, redirect: edit_survey_path(@s)}.to_json)
      q = Question.find(q.id)
      expect(q.warning).to be_false
      expect(q.require_comment).to be_false
      expect(q.require_attachment).to be_false
    end
    it 'should allow questions to have attachments' do
      q = @s.questions.create!(content: "Sample content", choices:"a\nb")
      q.save!
      q.attachments.create!(attached_file_name:"attachment1.jpg")
      post :update, {id: @s.id, survey: {name: 'survey name', questions_attributes: {q.id => {id: q.id, content: "Sample content"}}}}
      expect(response.body).to eq ({flash: {errors: nil}, redirect: edit_survey_path(@s)}.to_json)
      Question.find(q.id).should_not be_warning
    end
  end
  describe "create" do
    it "should reject if user does not have edit_survey permission" do
      @u.update_attributes(:survey_edit=>false)
      post :create, {:survey=>{:name=>'abc'}} 
      expect(response.body).to eq ({flash: {errors: ["You do not have permission to edit surveys."]}, redirect: nil}.to_json)
      expect(Survey.count).to eq 0
    end
    it "should pass if user has edit_survey permission" do
      post :create, {:survey=>{:name=>'abc'}} 
      expect(response.body).to eq ({flash: {errors: nil}, redirect: edit_survey_path(Survey.first)}.to_json)
      expect(Survey.first.name).to eq 'abc'
      expect(Survey.first.company_id).to eq @u.company_id
    end
    it "should set company_id based on current_user not parameter" do
      post :create, {:survey=>{:name=>'abc',:company_id => (@u.company_id+1)}} 
      parsed_response = JSON.parse response.body
      expect(parsed_response["redirect"]).to eq edit_survey_path(Survey.first)
      expect(parsed_response["flash"]["errors"]).to be_nil
      expect(Survey.first.company_id).to eq @u.company_id
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
      c = Factory(:company, name: "Z is my Company Name")
      @u.company.linked_companies << c

      Survey.any_instance.stub(:can_edit?).and_return(true)
      get :show_assign, :id=>@s.id
      response.should be_success
      assigns(:survey).should == @s
      assigns(:visible_companies).should eq [@u.company, @u.company.linked_companies.first]
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
      @dj_state = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false
      @s = Factory(:survey)
      SurveyResponse.any_instance.stub(:invite_user!) #don't want to deal with this except in the notify test
    end
    after :each do
      Delayed::Worker.delay_jobs = @dj_state
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
    it "should notify user when assigned" do
      u2 = Factory(:user)
      Survey.any_instance.stub(:can_edit?).and_return(true)
      sr = stub(:survey_response)
      sr.should_receive(:invite_user!)
      Survey.any_instance.should_receive(:generate_response!).and_return(sr)
      post :assign, :id=>@s.id, :assign=>{"0"=>u2.id.to_s}
    end
    it "should not assign if user cannot edit survey" do
      u2 = Factory(:user)
      Survey.any_instance.stub(:can_edit?).and_return(false)
      post :assign, :id=>@s.id, :assign=>{"0"=>u2.id.to_s}
      response.should redirect_to request.referrer
      flash[:errors].should have(1).item
    end
    it "should assign to the same user twice" do
      u2 = Factory(:user)
      Factory(:survey_response,:survey=>@s,:user=>u2) #making this one exist already
      u3 = Factory(:user) #this user should still have one created
      Survey.any_instance.stub(:can_edit?).and_return(true)
      post :assign, :id=>@s.id, :assign=>{"0"=>u2.id.to_s,"1"=>u3.id.to_s}
      response.should redirect_to survey_path(@s)
      flash[:notices].should have(1).messages
      SurveyResponse.find_by_survey_id_and_user_id(@s.id,u3.id).should_not be_nil
      SurveyResponse.where(:user_id=>u2.id,:survey_id=>@s.id).count.should == 2
    end
    it "should set subtitle" do
      u2 = Factory(:user)
      Survey.any_instance.stub(:can_edit?).and_return(true)
      post :assign, :id=>@s.id, :assign=>{"0"=>u2.id.to_s}, :subtitle=>'sub'
      response.should redirect_to survey_path(@s)
      SurveyResponse.find_by_survey_id_and_user_id(@s.id,u2.id).subtitle.should == 'sub'
    end
    it "assigns to groups" do
      g = Group.create! system_code: "g", name: "Group"
      Survey.any_instance.stub(:can_edit?).and_return(true)
      SurveyResponse.any_instance.should_receive(:invite_user!)
      post :assign, :id=>@s.id, :groups=>[g.id], :subtitle=>'sub'

      expect(response).to redirect_to @s
      expect(flash[:notices]).to include "1 group assigned."
      expect(SurveyResponse.where("group_id = ? AND subtitle = ? ", g.id, "sub").first).not_to be_nil
    end
    it "should associate with base_object" do
      Survey.any_instance.stub(:can_edit?).and_return(true)
      Company.any_instance.stub(:can_view?).and_return(true)
      expect {
        post :assign, :id=>@s.id, :assign=>{'0'=>@u.id.to_s}, :base_object_type => 'Company', :base_object_id => @u.company_id.to_s
      }.to change(SurveyResponse.where(base_object_id:@u.company_id,base_object_type:'Company'),:count).from(0).to(1)
      expect(flash[:errors]).to be_blank
      expect(response).to be_redirect
    end
    it "should error if user cannot view base_object" do
      Survey.any_instance.stub(:can_edit?).and_return(true)
      Company.any_instance.stub(:can_view?).and_return(false)
      expect {
        post :assign, :id=>@s.id, :assign=>{'0'=>@u.id.to_s}, :base_object_type => 'Company', :base_object_id => @u.company_id.to_s
      }.to_not change(SurveyResponse,:count)
      expect(flash[:errors].first).to match /not found/
    end
    it "should redirect to special path" do
      Survey.any_instance.stub(:can_edit?).and_return(true)
      post :assign, :id=>@s.id, :assign=>{'0'=>@u.id.to_s}, :redirect_to=>'/my_path'
      expect(response).to redirect_to '/my_path'
    end
    it "fails when no groups or users are selected" do
      Survey.any_instance.stub(:can_edit?).and_return(true)
      post :assign, :id=>@s.id, :subtitle=>'sub'
      expect(response).to redirect_to @s
      expect(flash[:errors]).to include "You must assign this survey to at least one user or group."
    end
  end
  describe "toggle subscription" do
    before :each do 
      @dj_state = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false
      @s = Factory(:survey, :company_id => @u.company_id)
    end
    after :each do
      Delayed::Worker.delay_jobs = @dj_state
    end
    it "should not create subscription if user cannot see surveys" do
      @u = Factory(:user,:survey_view => false)
      sign_in_as @u
      lambda do
        @u.survey_view = false
        get :toggle_subscription, :id => @s.id
      end.should change(SurveySubscription, :count).by(0)
    end
    it "should not create subscription if user and survey companies differ" do
      lambda do
        @s.update_attributes(:company_id => @u.company_id + 1)
        @u.survey_view = false
        get :toggle_subscription, :id => @s.id
      end.should change(SurveySubscription, :count).by(0)
    end
    it "should create subscription if user can view" do
      lambda do
        get :toggle_subscription, :id => @s.id
      end.should change(SurveySubscription, :count).by(1)
    end
    it "should destroy existing subscription" do
      subscription = Factory(:survey_subscription, :survey_id => @s.id, :user_id => @u.id)
      lambda do
        @s.update_attributes(:company_id => @u.company_id)
        get :toggle_subscription, :id => @s.id
      end.should change(SurveySubscription, :count).by(-1)
    end
  end

  describe "archive" do
    it "archives surveys" do
      to_find = Factory(:survey,:company=>@u.company)

      put :archive, id: to_find.id

      expect(response).to redirect_to survey_path(to_find)
      to_find.reload
      expect(to_find.archived?).to be_true
      expect(flash[:notices]).to include "Survey archived."
    end

    it "does not allow archiving of surveys user cannot edit" do
      to_find = Factory(:survey,:company=>@u.company)
      Survey.any_instance.should_receive(:can_edit?).and_return false

      put :archive, id: to_find.id
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to archive this Survey."
    end
  end

  describe "restore" do
    it "restores surveys" do
      to_find = Factory(:survey,:company=>@u.company, archived: true)

      put :restore, id: to_find.id

      expect(response).to redirect_to survey_path(to_find)
      to_find.reload
      expect(to_find.archived?).to be_false
      expect(flash[:notices]).to include "Survey restored."
    end

    it "does not allow restoring of surveys user cannot edit" do
      to_find = Factory(:survey,:company=>@u.company)
      Survey.any_instance.should_receive(:can_edit?).and_return false

      put :restore, id: to_find.id
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to restore this Survey."
    end
  end
end
