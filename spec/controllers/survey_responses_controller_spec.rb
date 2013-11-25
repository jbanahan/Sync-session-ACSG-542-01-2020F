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
    context :json do 
      it "should load json response" do
        q = Factory(:question,survey:Factory(:survey,name:'myname',ratings_list:"a\nb"))
        sr = q.survey.generate_response! @u, 'subt'
        get :show, :id=>sr.id, :format=>:json
        response.should be_success
        j = JSON.parse response.body
        srj = j['survey_response']
        srj['survey']['name'].should == sr.survey.name
        srj['survey']['rating_values'].should == ['a','b']
      end

      it "should remove private comments if user cannot edit" do
        SurveyResponse.any_instance.stub(:can_view?).and_return true
        SurveyResponse.any_instance.stub(:can_edit?).and_return false
        q = Factory(:question,survey:Factory(:survey,name:'myname',ratings_list:"a\nb"))
        sr = q.survey.generate_response! @u, 'subt'
        sr.answers.first.answer_comments.create!(content:'mycomment',private:false,user:@u)
        sr.answers.first.answer_comments.create!(content:'pcomment',private:true,user:@u)
        get :show, :id=>sr.id, :format=>:json
        response.should be_success
        j = JSON.parse response.body
        ac = j['survey_response']['answers'].first['answer_comments']
        ac.size.should == 1
        ac.first['content'].should == 'mycomment'
      end

      it "should leave private comments if user can edit" do
        SurveyResponse.any_instance.stub(:can_view?).and_return true
        SurveyResponse.any_instance.stub(:can_edit?).and_return true
        q = Factory(:question,survey:Factory(:survey,name:'myname',ratings_list:"a\nb"))
        sr = q.survey.generate_response! @u, 'subt'
        sr.answers.first.answer_comments.create!(content:'mycomment',private:false,user:@u)
        sr.answers.first.answer_comments.create!(content:'pcomment',private:true,user:@u)
        get :show, :id=>sr.id, :format=>:json
        response.should be_success
        j = JSON.parse response.body
        ac = j['survey_response']['answers'].first['answer_comments']
        ac.size.should == 2
        ac.collect {|c| c['content']}.should == ['mycomment','pcomment']
      end
    end
  end
  context 'authenticated' do
    before :each do
      activate_authlogic
      @survey_user = Factory(:user, survey_edit: true)
      @survey = Factory(:survey,:company=>@survey_user.company)
      @survey.questions.create!(:content=>'1234567890123456')
      @response_user = Factory(:user)
      @sr = Factory(:survey_response,:user=>@response_user,:survey=>@survey)
      @sr.answers.create!(:question=>@survey.questions.first)
    end
    describe 'update' do
      it "should not save if user is not from survey company or the user assigned to the response" do
        UserSession.create! Factory(:user)
        post :update, :id=>@sr.id
        response.should redirect_to root_path
        flash[:errors].should have(1).msg
        SurveyResponse.find(@sr.id).answers.first.choice.should be_nil
      end
      it "should not update submitted date if survey_response.user != current_user" do
        UserSession.create! @survey_user
        post :update, :id=>@sr.id, :do_submit=>"1"
        SurveyResponse.find(@sr.id).submitted_date.should be_nil 
      end
      it "should update submitted date if flag set and survey_response.user == current_user" do
        UserSession.create! @response_user
        post :update, :id=>@sr.id, :do_submit=>"1"
        SurveyResponse.find(@sr.id).submitted_date.should > 10.seconds.ago
      end
      it "should create update record" do
        UserSession.create! @response_user
        post :update, :id=>@sr.id, :do_submit=>"1"
        SurveyResponse.find(@sr.id).survey_response_updates.first.user.should == @response_user
      end
    end
    describe 'invite' do
      it "should allow survey company to send invite" do
        UserSession.create! @survey_user
        SurveyResponse.any_instance.should_receive(:invite_user!)
        get :invite, :id=>@sr.id
        response.should redirect_to @sr
      end
      it "should not allow another user to send invite" do
        UserSession.create! @response_user
        SurveyResponse.any_instance.should_not_receive(:invite_user!)
        get :invite, :id=>@sr.id
        response.should redirect_to request.referrer
      end
    end

    describe "archive" do
      it "should allow survey user to archive a survey response" do
        put :archive, :id => @sr.id
        @sr.reload.archived.should be_true
        flash[:notices].first.should == "The Survey Response for #{@response_user.full_name} has been archived."
        response.should redirect_to @survey
      end

      it "should not allow a user without edit privs to archive a survey response" do
        @survey_user.update_attributes survey_edit: false
        put :archive, :id => @sr.id
        @sr.reload.archived.should be_false
        flash[:errors].first.should == "You do not have permission to work with this survey."
      end
    end

    describe "restore" do
      it "should allow survey user to restore a survey response" do
        put :restore, :id => @sr.id
        @sr.reload.archived.should be_false
        flash[:notices].first.should == "The Survey Response for #{@response_user.full_name} has been restored."
        response.should redirect_to @survey
      end

      it "should not allow a user without edit privs to archive a survey response" do
        @sr.archived = true
        @sr.save!
        
        @survey_user.update_attributes survey_edit: false
        put :restore, :id => @sr.id
        @sr.reload.archived.should be_true
        flash[:errors].first.should == "You do not have permission to work with this survey."
      end
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
