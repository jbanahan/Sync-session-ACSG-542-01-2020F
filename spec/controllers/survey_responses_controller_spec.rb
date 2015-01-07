require 'spec_helper'

describe SurveyResponsesController do
  describe 'show' do
    before :each do

      @u = Factory(:user)
      sign_in_as @u
    end
    it 'should be respond mode if current_user == survey_response.user and not submitted' do
      sr = Factory(:survey_response,:user=>@u)
      get :show, :id=>sr.id
      assigns(:sr).should == sr
      assigns(:rate_mode).should be_false
      assigns(:respond_mode).should be_true
    end
    it 'should be respond mode if current_user is in survey group and not submitted' do
      group = Group.create! system_code: "g1"
      @u.groups << group
      sr = Factory(:survey_response, group: group)

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
    it "should mark response_opened_date if current_user is in response group and response_opened_date.nil?" do
      group = Group.create! system_code: "g1"
      @u.groups << group

      sr = Factory(:survey_response, group: group)
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
    it "should show error if user is using old IE version" do
      @request.user_agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB7.4; InfoPath.2; SV1; .NET CLR 3.3.69573; WOW64; en-US)"
      sr = Factory(:survey_response,:user=>@u)
      get :show, :id=>sr.id
      expect(response).to be_success
      expect(flash[:errors]).to include "You are using an unsupported version of Internet Explorer.  Upgrade to at least version 9 or consider using Google Chrome before filling in any survey answers."
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
        a = srj['answers'].first
        expect(a['question']['require_comment']).to be_false
        expect(a['question']['require_attachment']).to be_false
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

      context "archived" do
        it "disables all can_* attributes on archived survey responses" do
          sr = Factory(:survey_response, user:@u, archived: true)
          get :show, :id=>sr.id, :format=>:json
          expect(response).to be_success
          j = JSON.parse response.body

          expect(j['survey_response']['archived']).to be_true
          expect(j['survey_response']['can_rate']).to be_false
          expect(j['survey_response']['can_answer']).to be_false
          expect(j['survey_response']['can_submit']).to be_false
          expect(j['survey_response']['can_make_private_comment']).to be_false
        end

        it "disables all can_* attributes on survey responses associated with an archvied survey" do
          sr = Factory(:survey_response, user:@u, archived: false)
          sr.survey.update_attributes! archived: true
          
          get :show, :id=>sr.id, :format=>:json
          expect(response).to be_success
          j = JSON.parse response.body

          expect(j['survey_response']['archived']).to be_true
          expect(j['survey_response']['can_rate']).to be_false
          expect(j['survey_response']['can_answer']).to be_false
          expect(j['survey_response']['can_submit']).to be_false
          expect(j['survey_response']['can_make_private_comment']).to be_false
        end
      end
    end
  end
  context 'authenticated' do
    before :each do

      @survey_user = Factory(:user, survey_edit: true)
      @survey = Factory(:survey,:company=>@survey_user.company)
      @survey.questions.create!(:content=>'1234567890123456')
      @response_user = Factory(:user)
      @sr = Factory(:survey_response,:user=>@response_user,:survey=>@survey)
      @sr.answers.create!(:question=>@survey.questions.first)
    end
    describe 'update' do
      it "should not save if user is not from survey company or the user assigned to the response" do
        sign_in_as Factory(:user)
        post :update, :id=>@sr.id
        response.should redirect_to root_path
        flash[:errors].should have(1).msg
        SurveyResponse.find(@sr.id).answers.first.choice.should be_nil
      end
      it "should not update submitted date if survey_response.user != current_user" do
        sign_in_as @survey_user
        post :update, :id=>@sr.id, :do_submit=>"1"
        SurveyResponse.find(@sr.id).submitted_date.should be_nil 
      end
      it "should update submitted date if flag set and survey_response.user == current_user" do
        sign_in_as @response_user
        post :update, :id=>@sr.id, :do_submit=>"1"
        SurveyResponse.find(@sr.id).submitted_date.should > 10.seconds.ago
      end
       it "should update submitted date if flag set and user is in survey response user group" do
        group_user = Factory(:user)
        group = Group.create! system_code: "g1"
        group_user.groups << group
        @sr.update_attributes! group: group
        sign_in_as group_user
        post :update, :id=>@sr.id, :do_submit=>"1"
        expect(response).to redirect_to @sr
        SurveyResponse.find(@sr.id).submitted_date.should > 10.seconds.ago
      end
      it "should create update record" do
        sign_in_as @response_user
        post :update, :id=>@sr.id, :do_submit=>"1"
        SurveyResponse.find(@sr.id).survey_response_updates.first.user.should == @response_user
      end
    end
    describe 'invite' do
      it "should allow survey company to send invite" do
        sign_in_as @survey_user
        SurveyResponse.any_instance.should_receive(:invite_user!)
        get :invite, :id=>@sr.id
        response.should redirect_to @sr
      end
      it "should not allow another user to send invite" do
        sign_in_as @response_user
        SurveyResponse.any_instance.should_not_receive(:invite_user!)
        get :invite, :id=>@sr.id
        response.should redirect_to request.referrer
      end
    end

    describe "archive" do
      it "should allow survey user to archive a survey response" do
        sign_in_as @survey_user
        put :archive, :id => @sr.id
        @sr.reload.archived.should be_true
        flash[:notices].first.should == "The Survey Response for #{@response_user.full_name} has been archived."
        response.should redirect_to @survey
      end

      it "should not allow a user without edit privs to archive a survey response" do
        @survey_user.update_attributes survey_edit: false
        sign_in_as @survey_user
        put :archive, :id => @sr.id
        @sr.reload.archived.should be_false
        flash[:errors].first.should == "You do not have permission to work with this survey."
      end
    end

    describe "restore" do
      it "should allow survey user to restore a survey response" do
        sign_in_as @survey_user
        put :restore, :id => @sr.id
        @sr.reload.archived.should be_false
        flash[:notices].first.should == "The Survey Response for #{@response_user.full_name} has been restored."
        response.should redirect_to @survey
      end

      it "should not allow a user without edit privs to archive a survey response" do
        @sr.archived = true
        @sr.save!
        
        @survey_user.update_attributes survey_edit: false
        sign_in_as @survey_user
        put :restore, :id => @sr.id
        @sr.reload.archived.should be_true
        flash[:errors].first.should == "You do not have permission to work with this survey."
      end
    end
  end
  describe 'index' do
    before :each do

      @u = Factory(:user)
      sign_in_as @u
    end
    it 'should only show survey responses assigned to current_user' do
      to_find = Factory(:survey_response,:user=>@u)
      dont_find = Factory(:survey_response)
      group = Group.create! system_code: "g"
      @u.groups << group
      group_find = Factory(:survey_response, group: group)

      get :index
      response.should be_success
      srs = assigns(:survey_responses).to_a
      expect(srs).to include to_find
      expect(srs).to include group_find
    end


    it "shows error if user is using IE < 9" do
      @request.user_agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB7.4; InfoPath.2; SV1; .NET CLR 3.3.69573; WOW64; en-US)"
      to_find = Factory(:survey_response,:user=>@u)
      get :index
      expect(response).to be_success
      expect(flash[:errors]).to include "You are using an unsupported version of Internet Explorer.  Upgrade to at least version 9 or consider using Google Chrome before filling in any survey answers."
    end
  end
end
