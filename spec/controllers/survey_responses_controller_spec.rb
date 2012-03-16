require 'spec_helper'

describe SurveyResponsesController do
  describe 'show' do
    before :each do
      activate_authlogic
      @u = Factory(:user)
      UserSession.create! @u
    end
    it 'should be respond mode if current_user == survey_response.user and not submitted' do
      sr = Factory(:survey_response,:user=>@u)
      get :show, :id=>sr.id
      assigns(:sr).should == sr
      assigns(:rate_mode).should be_false
      assigns(:respond_mode).should be_true
    end
    it 'should not be respond mode if submitted' do
      sr = Factory(:survey_response,:user=>@u,:submitted_date=>1.day.ago)
      get :show, :id=>sr.id
      assigns(:sr).should == sr
      assigns(:rate_mode).should be_false
      assigns(:respond_mode).should be_false
    end
    it 'should be rate mode if current_user.edit_surveys? && current_user.company == survey_response.survey.company and survey_response.submitted_date' do
      @u.update_attributes(:survey_edit=>true)
      sr = Factory(:survey_response,:survey=>Factory(:survey,:company=>@u.company),:submitted_date=>1.day.ago)
      get :show, :id=>sr.id
      assigns(:sr).should == sr
      assigns(:rate_mode).should be_true
      assigns(:respond_mode).should be_false
    end
    it 'should not be rate mode if not submitted' do
      @u.update_attributes(:survey_edit=>true)
      sr = Factory(:survey_response,:survey=>Factory(:survey,:company=>@u.company))
      get :show, :id=>sr.id
      assigns(:sr).should == sr
      assigns(:rate_mode).should be_false
      assigns(:respond_mode).should be_false
    end
    it "should not display if it doesn't pass the other tests" do
      sr = Factory(:survey_response)
      get :show, :id=>sr.id
      response.should redirect_to root_path
      flash[:errors].count.should == 1
    end
    it "should mark response_opened_date if current_user == survey_response.user and response_opened_date.nil?" do
      sr = Factory(:survey_response,:user=>@u)
      get :show, :id=>sr.id
      SurveyResponse.find(sr.id).response_opened_date.should > 2.minutes.ago
    end
    it "should not change response_opened_date if already set" do
      d = 10.hours.ago
      sr = Factory(:survey_response,:user=>@u,:response_opened_date=>d)
      get :show, :id=>sr.id
      SurveyResponse.find(sr.id).response_opened_date.to_i.should == d.to_i
    end
    it "should not set respond mode if response is submitted" do
      sr = Factory(:survey_response,:user=>@u, :submitted_date=>0.seconds.ago)
      get :show, :id=>sr.id
      assigns(:sr).should == sr
      assigns(:respond_mode).should be_false
    end
  end
  describe 'update' do
    before :each do
      activate_authlogic
      @survey_user = Factory(:user)
      @survey = Factory(:survey,:company=>@survey_user.company)
      @survey.questions.create!(:content=>'1234567890123456')
      @response_user = Factory(:user)
      @sr = Factory(:survey_response,:user=>@response_user,:survey=>@survey)
      @sr.answers.create!(:question=>@survey.questions.first)
    end
    it "should not change ratings if user is not from survey company" do
      UserSession.create! @response_user
      post :update, :id=>@sr.id, :survey_response=>{"answers_attributes"=>{"1"=>{"choice"=>"a","id"=>@sr.answers.first.id.to_s,"rating"=>"x"}}}
      response.should redirect_to survey_response_path(@sr)
      flash[:notices].should have(1).message
      answers = SurveyResponse.find(@sr.id).answers
      answers.should have(1).answer
      a = answers.first
      a.choice.should == "a"
      a.rating.should be_nil
    end
    it "should not save if user is not from survey company or the user assigned to the response" do
      UserSession.create! Factory(:user)
      post :update, :id=>@sr.id, :survey_response=>{"answers_attributes"=>{"1"=>{"choice"=>"a","id"=>@sr.answers.first.id.to_s,"rating"=>"x"}}}
      response.should redirect_to root_path
      flash[:errors].should have(1).msg
      SurveyResponse.find(@sr.id).answers.first.choice.should be_nil
    end
    it "should not change choices if survey_response.user != current_user" do
      UserSession.create! @survey_user
      post :update, :id=>@sr.id, :survey_response=>{"answers_attributes"=>{"1"=>{"choice"=>"a","id"=>@sr.answers.first.id.to_s,"rating"=>"x"}}}
      response.should redirect_to survey_response_path(@sr)
      flash[:notices].should have(1).message
      answers = SurveyResponse.find(@sr.id).answers
      answers.should have(1).answer
      a = answers.first
      a.choice.should be_nil
      a.rating.should == "x"
    end
    it "should add comments" do
      UserSession.create! @response_user
      post :update, :id=>@sr.id, :survey_response=>{"answers_attributes"=>{"1"=>{"choice"=>"a","id"=>@sr.answers.first.id.to_s,
        "answer_comments_attributes"=>{"1"=>{"user_id"=>@response_user.id,"content"=>"abc"}}}}}
      response.should redirect_to survey_response_path @sr
      flash[:notices].should have(1).message
      ac = SurveyResponse.find(@sr.id).answers.first.answer_comments.first
      ac.content.should == "abc"
      ac.user.should == @response_user
    end
    it "should not add comments if comment.user != current_user" do
      UserSession.create! @response_user
      post :update, :id=>@sr.id, :survey_response=>{"answers_attributes"=>{"1"=>{"choice"=>"a","id"=>@sr.answers.first.id.to_s,
        "answer_comments_attributes"=>{"1"=>{"user_id"=>@survey_user.id,"content"=>"abc"}}}}}
      response.should redirect_to survey_response_path @sr
      flash[:notices].should have(1).message
      SurveyResponse.find(@sr.id).answers.first.answer_comments.should be_empty
    end
    it "should not update submitted date if survey_response.user != current_user" do
      UserSession.create! @survey_user
      post :update, :id=>@sr.id, :survey_response=>{"answers_attributes"=>{"1"=>{"choice"=>"a","id"=>@sr.answers.first.id.to_s,"rating"=>"x"}}}, :do_submit=>"1"
      SurveyResponse.find(@sr.id).submitted_date.should be_nil 
    end
    it "should update submitted date if flag set and survey_response.user == current_user" do
      UserSession.create! @response_user
      post :update, :id=>@sr.id, :survey_response=>{"answers_attributes"=>{"1"=>{"choice"=>"a","id"=>@sr.answers.first.id.to_s,"rating"=>"x"}}}, :do_submit=>"1"
      SurveyResponse.find(@sr.id).submitted_date.should > 10.seconds.ago
    end
  end
  describe 'index' do
    before :each do
      activate_authlogic
      @u = Factory(:user)
      UserSession.create! @u
    end
    it 'should only show survey responses assigned to current_user' do
      to_find = Factory(:survey_response,:user=>@u)
      dont_find = Factory(:survey_response)
      get :index
      response.should be_success
      assigns(:survey_responses).to_a.should == [to_find]
    end
  end
end
