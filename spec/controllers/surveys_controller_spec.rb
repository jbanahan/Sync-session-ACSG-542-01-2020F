describe SurveysController do
  let(:user) { FactoryBot(:user, survey_view: true, survey_edit: true) }
  let(:controller) { @controller } # rubocop:disable RSpec/InstanceVariable

  before do
    sign_in_as user
  end

  describe 'index' do
    it "only shows surveys for logged in company" do
      to_find = FactoryBot(:survey, company: user.company)
      FactoryBot(:survey, company: user.company, archived: true)
      FactoryBot(:survey)
      get :index
      expect(assigns(:surveys)).to eq [to_find]
      expect(assigns(:archived_surveys)).to be_nil
    end

    it "rejects if user does not have view_survey permission" do
      user.update(survey_view: false)
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "shows archived surveys if prompted" do
      to_find = FactoryBot(:survey, company: user.company)
      archived = FactoryBot(:survey, company: user.company, archived: true)
      get :index, show_archived: true

      expect(assigns(:surveys)).to eq [to_find]
      expect(assigns(:archived_surveys)).to eq [archived]
    end
  end

  describe 'new' do
    it "rejects if user does not have edit_survey permission" do
      user.update(survey_edit: false)
      get :new
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "passes if user has edit_survey permission" do
      get :new
      expect(assigns(:survey).id).to be_nil
    end
  end

  describe "show" do
    let(:survey) { FactoryBot(:survey, company_id: user.company_id, name: "Name") }

    it "fails if user doesn't have view survey permission" do
      user.update(survey_view: false)
      get :show, id: survey.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "fails if company_id != current_user.company_id" do
      survey.update(company_id: user.company_id + 1)
      get :show, id: survey.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "sets survey variable" do
      get :show, id: survey.id
      expect(assigns(:survey)).to eq(survey)
    end

    it "writes excel file for excel formats" do
      wb = instance_double('wb')
      expect(Survey).to receive(:find).with(survey.id.to_s).and_return(survey)
      expect(survey).to receive(:to_xls).and_return(wb)
      expect(wb).to receive(:write) do |io|
        io.string = "Test"
      end
      expect(controller).to receive(:send_data) do |data, options|
        expect(data).to eq("Test")
        expect(options[:type]).to eq(:xls)
        expect(options[:filename]).to eq(survey.name + ".xls")

        # Need this so the controller knows some template was utilized (since we mocked
        # away the send_data call)
        controller.render nothing: true
      end

      get :show, {id: survey.id, format: :xls}
    end

    it "handles surveys with no names" do
      wb = double
      survey.name = ""
      expect(Survey).to receive(:find).with(survey.id.to_s).and_return(survey)
      expect(survey).to receive(:to_xls).and_return(wb)
      expect(wb).to receive(:write)

      expect(controller).to receive(:send_data) do |_data, options|
        expect(options[:filename]).to eq("survey.xls")

        controller.render nothing: true
      end

      get :show, {id: survey.id,  format: :xls}
    end

    it "enables showing archived responses" do
      get :show, {:id => survey.id, "show_archived_responses" => "true"}
      expect(assigns(:show_archived)).to be_truthy
    end

    it "does not enable showing archived responses for users with no edit privs" do
      user.update survey_edit: false
      get :show, {:id => survey.id, "show_archived_responses" => "true"}
      expect(assigns(:show_archived)).to be_falsey
    end

  end

  describe "edit" do
    let(:survey) { FactoryBot(:survey, company_id: user.company_id) }

    it "rejects if survey is locked" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      expect_any_instance_of(Survey).to receive(:locked?).and_return(true)
      get :edit, id: survey.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "rejects if user cannot edit" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(false)
      get :edit, id: survey.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "passes if user has edit_survey permission" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      allow_any_instance_of(Survey).to receive(:locked?).and_return(false)
      get :edit, id: survey.id
      expect(assigns(:survey)).to eq(survey)
    end
  end

  describe "update" do
    let(:survey) { FactoryBot(:survey, company_id: user.company_id) }

    it "rejects is survey is locked" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      expect_any_instance_of(Survey).to receive(:locked?).and_return(true)
      post :update, id: survey.id
      expect(response.body).to eq ({flash: {errors: ["You cannot edit a survey that has already been sent."]}, redirect: edit_survey_path(survey)}.to_json)
    end

    it "rejects if user cannot edit" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(false)
      post :update, id: survey.id
      expect(response.body).to eq ({flash: {errors: ["You cannot edit this survey."]}, redirect: edit_survey_path(survey)}.to_json)
    end

    it "passes if user has edit_survey permission" do
      post :update, {id: survey.id, survey: {name: 'abcdef'}}
      expect(response.body).to eq ({flash: {errors: nil}, redirect: edit_survey_path(survey)}.to_json)
      expect(Survey.find(survey.id).name).to eq 'abcdef'
    end

    it "clears warnings" do
      q = survey.questions.create!(content: "ABC def 123", choices: "a\nb", warning: true, require_comment: true, require_attachment: true)
      post :update, {id: survey.id, survey: {name: 'abcdef', questions_attributes: {q.id => {id: q.id, content: "ABC def 123"}}}}
      expect(response.body).to eq ({flash: {errors: nil}, redirect: edit_survey_path(survey)}.to_json)
      q = Question.find(q.id)
      expect(q.warning).to be_falsey
      expect(q.require_comment).to be_falsey
      expect(q.require_attachment).to be_falsey
    end

    it "does not change the rank of questions that already have a rank" do
      q = survey.questions.create!(content: "Sample content", choices: "a\nb")
      q.save!
      post :update, {id: survey.id, survey: {name: 'survey name', questions_attributes: {q.id => {id: q.id, content: "Sample content"}}}}
      expect(Question.first.rank).to eq(0)
    end

    it 'allows questions to have attachments' do
      q = survey.questions.create!(content: "Sample content", choices: "a\nb")
      q.save!
      q.attachments.create!(attached_file_name: "attachment1.jpg")
      post :update, {id: survey.id, survey: {name: 'survey name', questions_attributes: {q.id => {id: q.id, content: "Sample content"}}}}
      expect(response.body).to eq ({flash: {errors: nil}, redirect: edit_survey_path(survey)}.to_json)
      expect(Question.find(q.id)).not_to be_warning
    end
  end

  describe "create" do
    it "rejects if user does not have edit_survey permission" do
      user.update(survey_edit: false)
      post :create, {survey: {name: 'abc'}}
      expect(response.body).to eq ({flash: {errors: ["You do not have permission to edit surveys."]}, redirect: nil}.to_json)
      expect(Survey.count).to eq 0
    end

    it "passes if user has edit_survey permission" do
      post :create, {survey: {name: 'abc'}}
      expect(response.body).to eq ({flash: {errors: nil}, redirect: edit_survey_path(Survey.first)}.to_json)
      expect(Survey.first.name).to eq 'abc'
      expect(Survey.first.company_id).to eq user.company_id
    end

    it "sets the rank of new questions" do
      post :create, {survey: {name: 'abc', questions_attributes:           {"1496153505004" =>
               {"content" => "It's a question",
                "choices" => "blah",
                "rank" => "",
                "comment_required_for_choices" => "",
                "attachment_required_for_choices" => ""}}}}
      expect(Question.first.rank).to be(0)
    end

    it "sets company_id based on current_user not parameter" do
      post :create, {survey: {name: 'abc', company_id: (user.company_id + 1)}}
      parsed_response = JSON.parse response.body
      expect(parsed_response["redirect"]).to eq edit_survey_path(Survey.first)
      expect(parsed_response["flash"]["errors"]).to be_nil
      expect(Survey.first.company_id).to eq user.company_id
    end

    it "sets created_by to current_user" do
      post :create, {survey: {name: 'abc'}}
      expect(Survey.first.created_by).to eq(user)
    end
  end

  describe "destroy" do
    let(:survey) { FactoryBot(:survey, company_id: user.company_id) }

    it "rejects if survey is locked" do
      expect_any_instance_of(Survey).to receive(:locked?).and_return(true)
      delete :destroy, id: survey.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      expect(Survey.find(survey.id)).to eq(survey) # not deleted
    end

    it "rejects if user cannot edit" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(false)
      delete :destroy, id: survey.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      expect(Survey.find(survey.id)).to eq(survey) # not deleted
    end

    it "passes if user can edit" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      delete :destroy, id: survey.id
      expect(response).to redirect_to surveys_path
      expect(flash[:notices].first).to eq("Survey deleted successfully.")
      expect(Survey.count).to eq(0)
    end
  end

  describe "show_assign" do
    let(:survey) { FactoryBot(:survey, company_id: user.company_id) }

    it "shows assignment page if user can edit survey" do
      c = FactoryBot(:company, name: "Z is my Company Name")
      user.company.linked_companies << c

      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      get :show_assign, id: survey.id
      expect(response).to be_success
      expect(assigns(:survey)).to eq(survey)
      expect(assigns(:visible_companies)).to eq [user.company, user.company.linked_companies.first]
    end

    it "does not show assignment if user cannot edit survey" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(false)
      get :show_assign, id: survey.id
      expect(response).to redirect_to request.referer
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "assign", :disable_delayed_jobs do
    let(:survey) { FactoryBot(:survey) }

    before do
      allow_any_instance_of(SurveyResponse).to receive(:invite_user!) # don't want to deal with this except in the notify test
    end

    it "assigns if user can edit survey" do
      u2 = FactoryBot(:user)
      u3 = FactoryBot(:user)
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      post :assign, id: survey.id, assign: {"0" => u2.id.to_s, "1" => u3.id.to_s}
      expect(response).to redirect_to survey_path(survey)
      expect(flash[:notices].size).to eq(1)
      expect(SurveyResponse.find_by(survey: survey.id, user: u2.id)).not_to be_nil
      expect(SurveyResponse.find_by(survey: survey.id, user: u3.id)).not_to be_nil
    end

    it "notifies user when assigned" do
      u2 = FactoryBot(:user)
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      sr = instance_double('survey_response')
      expect(sr).to receive(:invite_user!)
      expect_any_instance_of(Survey).to receive(:generate_response!).and_return(sr)
      post :assign, id: survey.id, assign: {"0" => u2.id.to_s}
    end

    it "does not assign if user cannot edit survey" do
      u2 = FactoryBot(:user)
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(false)
      post :assign, id: survey.id, assign: {"0" => u2.id.to_s}
      expect(response).to redirect_to request.referer
      expect(flash[:errors].size).to eq(1)
    end

    it "assigns to the same user twice" do
      u2 = FactoryBot(:user)
      FactoryBot(:survey_response, survey: survey, user: u2) # making this one exist already
      u3 = FactoryBot(:user) # this user should still have one created
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      post :assign, id: survey.id, assign: {"0" => u2.id.to_s, "1" => u3.id.to_s}
      expect(response).to redirect_to survey_path(survey)
      expect(flash[:notices].size).to eq(1)
      expect(SurveyResponse.find_by(survey: survey.id, user: u3.id)).not_to be_nil
      expect(SurveyResponse.where(user_id: u2.id, survey_id: survey.id).count).to eq(2)
    end

    it "sets subtitle" do
      u2 = FactoryBot(:user)
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      post :assign, id: survey.id, assign: {"0" => u2.id.to_s}, subtitle: 'sub'
      expect(response).to redirect_to survey_path(survey)
      expect(SurveyResponse.find_by(survey: survey.id, user: u2.id).subtitle).to eq('sub')
    end

    it "assigns to groups" do
      g = Group.create! system_code: "g", name: "Group"
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      expect_any_instance_of(SurveyResponse).to receive(:invite_user!)
      post :assign, id: survey.id, groups: [g.id], subtitle: 'sub'

      expect(response).to redirect_to survey
      expect(flash[:notices]).to include "1 group assigned."
      expect(SurveyResponse.where("group_id = ? AND subtitle = ? ", g.id, "sub").first).not_to be_nil
    end

    it "associates with base_object" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      allow_any_instance_of(Company).to receive(:can_view?).and_return(true)
      expect do
        post :assign, id: survey.id, assign: {'0' => user.id.to_s}, base_object_type: 'Company', base_object_id: user.company_id.to_s
      end.to change(SurveyResponse.where(base_object_id: user.company_id, base_object_type: 'Company'), :count).from(0).to(1)
      expect(flash[:errors]).to be_blank
      expect(response).to be_redirect
    end

    it "errors if user cannot view base_object" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      allow_any_instance_of(Company).to receive(:can_view?).and_return(false)
      expect do
        post :assign, id: survey.id, assign: {'0' => user.id.to_s}, base_object_type: 'Company', base_object_id: user.company_id.to_s
      end.not_to change(SurveyResponse, :count)
      expect(flash[:errors].first).to match(/not found/)
    end

    it "redirects to special path" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      post :assign, id: survey.id, assign: {'0' => user.id.to_s}, redirect_to: '/my_path'
      expect(response).to redirect_to '/my_path'
    end

    it "fails when no groups or users are selected" do
      allow_any_instance_of(Survey).to receive(:can_edit?).and_return(true)
      post :assign, id: survey.id, subtitle: 'sub'
      expect(response).to redirect_to survey
      expect(flash[:errors]).to include "You must assign this survey to at least one user or group."
    end
  end

  describe "toggle subscription", :disable_delayed_jobs do
    let(:survey) { FactoryBot(:survey, company_id: user.company_id) }

    it "does not create subscription if user cannot see surveys" do
      user = FactoryBot(:user, survey_view: false)
      sign_in_as user
      expect do
        user.survey_view = false
        get :toggle_subscription, id: survey.id
      end.to change(SurveySubscription, :count).by(0)
    end

    it "does not create subscription if user and survey companies differ" do
      expect do
        survey.update(company_id: user.company_id + 1)
        user.survey_view = false
        get :toggle_subscription, id: survey.id
      end.to change(SurveySubscription, :count).by(0)
    end

    it "creates subscription if user can view" do
      expect do
        get :toggle_subscription, id: survey.id
      end.to change(SurveySubscription, :count).by(1)
    end

    it "destroys existing subscription" do
      FactoryBot(:survey_subscription, survey_id: survey.id, user_id: user.id)
      expect do
        survey.update(company_id: user.company_id)
        get :toggle_subscription, id: survey.id
      end.to change(SurveySubscription, :count).by(-1)
    end
  end

  describe "archive" do
    it "archives surveys" do
      to_find = FactoryBot(:survey, company: user.company)

      put :archive, id: to_find.id

      expect(response).to redirect_to survey_path(to_find)
      to_find.reload
      expect(to_find.archived?).to be_truthy
      expect(flash[:notices]).to include "Survey archived."
    end

    it "does not allow archiving of surveys user cannot edit" do
      to_find = FactoryBot(:survey, company: user.company)
      expect_any_instance_of(Survey).to receive(:can_edit?).and_return false

      put :archive, id: to_find.id
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to archive this Survey."
    end
  end

  describe "restore" do
    it "restores surveys" do
      to_find = FactoryBot(:survey, company: user.company, archived: true)

      put :restore, id: to_find.id

      expect(response).to redirect_to survey_path(to_find)
      to_find.reload
      expect(to_find.archived?).to be_falsey
      expect(flash[:notices]).to include "Survey restored."
    end

    it "does not allow restoring of surveys user cannot edit" do
      to_find = FactoryBot(:survey, company: user.company)
      expect_any_instance_of(Survey).to receive(:can_edit?).and_return false

      put :restore, id: to_find.id
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to restore this Survey."
    end
  end
end
