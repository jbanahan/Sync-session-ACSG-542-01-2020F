describe Survey do
  describe "copy!" do
    before :each do
      @survey = create(:survey, :name=>"my name", :email_subject=>"emlsubj", :email_body=>"emlbod", :ratings_list=>"rat")
    end
    it 'should copy all questions with new ids' do
      q1 = create(:question, :rank=>1, :survey_id=>@survey.id, :content=>'my question content 1', :choices=>"x", :warning=>true)
      q2 = create(:question, :rank=>2, :survey_id=>@survey.id, :content=>'my question content 2')
      q3 = create(:question, :rank=>3, :survey_id=>@survey.id, :content=>'my question content 3')
      new_survey = @survey.copy!
      expect(new_survey.id).to be > 0
      expect(new_survey.id).not_to eq(@survey.id)
      expect(new_survey.company_id).to eq(@survey.company_id)
      expect(new_survey.name).to eq(@survey.name)
      expect(new_survey.email_subject).to eq(@survey.email_subject)
      expect(new_survey.email_body).to eq(@survey.email_body)
      expect(new_survey.ratings_list).to eq(@survey.ratings_list)
      expect(new_survey.questions.size).to eq(3)
      n1 = new_survey.questions.where(:rank=>1).first
      expect(n1.content).to eq(q1.content)
      expect(n1.choices).to eq(q1.choices)
      expect(n1.warning).to eq(q1.warning)
      expect(new_survey.questions.where(:rank=>2).first.content).to eq(q2.content)
      expect(new_survey.questions.where(:rank=>3).first.content).to eq(q3.content)
    end
    it 'should not copy subscriptions' do
      @survey.survey_subscriptions.create!(:user_id=>create(:user).id)
      expect(@survey.copy!.survey_subscriptions).to be_blank
    end
    it 'should not copy assigned users' do
      @survey.generate_response! create(:user)
      expect(@survey.copy!.assigned_users).to be_blank
    end
    it 'should not copy responses' do
      @survey.generate_response! create(:user)
      expect(@survey.copy!.survey_responses).to be_blank
    end
  end
  it 'should link to user' do
    u = create(:user)
    s = create(:survey, :created_by_id=>u.id)
    expect(s.created_by).to eq(u)
  end
  it "should be locked if responses exist" do
    sr = create(:survey_response)
    expect(sr.survey).to be_locked
  end
  it 'should not allow edits if locked' do
    s = create(:survey)
    allow(s).to receive(:has_responses?).and_return(true)
    expect(s.save).to be_falsey
    expect(s.errors.full_messages.first).to eq("You cannot change a locked survey.")
  end
  it "should update nested questions" do
    s = create(:survey)
    s.update_attributes(:questions_attributes=>[{:content=>'1234567890', :rank=>2}, {:content=>"09876543210", :rank=>1}])
    s = Survey.find(s.id)
    expect(s.questions.find_by(content: "09876543210").rank).to eq(1)
    expect(s.questions.find_by(content: "1234567890").rank).to eq(2)
  end
  describe 'generate_response' do
    it 'should make a response with all answers' do
      u = create(:user)
      s = create(:survey)
      s.update_attributes(:questions_attributes=>[{:content=>'1234567890', :rank=>2}, {:content=>"09876543210", :rank=>1}])
      sr = s.generate_response! u, "abc"
      expect(sr.answers.size).to eq 2
      expect(sr.survey_response_logs.where(:message=>"Survey assigned to #{u.full_name}").size).to eq 1
      expect(sr.subtitle).to eq "abc"
    end
  end
  describe 'generate_group_response' do
    it 'should make a response with all answers' do
      u = create(:user)
      group = Group.create! system_code: "G", name: "Group"
      u.groups << group
      s = create(:survey)
      s.update_attributes(:questions_attributes=>[{:content=>'1234567890', :rank=>2}, {:content=>"09876543210", :rank=>1}])
      sr = s.generate_group_response! group, 'abc'
      expect(sr.answers.size).to eq 2
      expect(sr.survey_response_logs.where(:message=>"Survey assigned to group #{group.name}").size).to eq 1
      expect(sr.subtitle).to eq "abc"
    end
  end
  describe "assigned_users" do
    it "should return all assigned users" do
      u1 = create(:user)
      u2 = create(:user)
      u3 = create(:user)
      s = create(:survey)
      s.generate_response! u1
      s.generate_response! u2
      # no response for user 3

      expect(s.assigned_users).to eq([u1, u2])
    end
  end
  describe "can_edit?" do
    before :each do
      @s = create(:survey)
    end
    it "should allow editing if user has permission and is from survey's company" do
      u = create(:user, :company=>@s.company, :survey_edit=>true)
      expect(@s.can_edit?(u)).to be_truthy
    end
    it "should not allow editing if user doesn't have permission" do
      u = create(:user, :company=>@s.company)
      expect(@s.can_edit?(u)).to be_falsey
    end
    it "should not allow editing if user isn't from survey's company" do
      u = create(:user, :survey_edit=>true)
      expect(@s.can_edit?(u)).to be_falsey
    end
  end
  describe "can_view?" do
    before :each do
      @s = create(:survey)
    end
    it "should allow view/download if user has permission and is from survey's company" do
      u = create(:user, :company=>@s.company, :survey_edit=>true)
      expect(@s.can_view?(u)).to be_truthy
    end
    it "should not allow view/download if user doesn't have permission" do
      u = create(:user, :company=>@s.company)
      expect(@s.can_view?(u)).to be_falsey
    end
    it "should not allow view/download if user isn't from survey's company" do
      u = create(:user, :survey_edit=>true)
      expect(@s.can_view?(u)).to be_falsey
    end
  end
  describe "rating_values" do
    it "should return empty array if no values" do
      expect(Survey.new.rating_values).to eq([])
    end
    it "should return values, one per line" do
      vals = "a\nb"
      expect(Survey.new(:ratings_list=>vals).rating_values).to eq(["a", "b"])
    end
  end
  describe "to_xls" do
    before :each do
      @survey = create(:survey, :name=>"my name", :email_subject=>"emlsubj", :email_body=>"emlbod", :ratings_list=>"1\n2")
      @q1 = create(:question, :rank=>1, :survey_id=>@survey.id, :content=>'my question content 1', :choices=>"x", :warning=>true)
      @q2 = create(:question, :rank=>2, :survey_id=>@survey.id, :content=>'my question content 2')

      @r1 = create(:survey_response, :survey_id=>@survey.id, :subtitle=>"sub", :rating=>"rat", :email_sent_date=>Time.now, :response_opened_date=>Time.now, :submitted_date=>Time.now)
      @r2 = create(:survey_response, :survey_id=>@survey.id, :subtitle=>"sub2", :submitted_date=>Time.now)
      @r3 = create(:survey_response, :survey_id=>@survey.id, :submitted_date=>nil)
      # Add archived response, which who's answer shouldn't show in the stats tested below
      @r4 = create(:survey_response, :survey_id=>@survey.id, :subtitle=>"sub", :rating=>"rat", :email_sent_date=>Time.now, :response_opened_date=>Time.now, :submitted_date=>Time.now, :archived=>true)


      @a1 = create(:answer, :question_id=>@q1.id, :rating=>"1", :survey_response_id=>@r1.id)
      @a2 = create(:answer, :question_id=>@q2.id, :rating=>"2", :survey_response_id=>@r2.id)
      @a3 = create(:answer, :question_id=>@q1.id, :rating=>"2", :survey_response_id=>@r3.id)
      @a4 = create(:answer, :question_id=>@q1.id, :rating=>"1", :survey_response_id=>@r4.id)
    end

    it "should create an excel file" do
      wb = @survey.to_xls
      responses = wb.worksheet 'Survey Responses'
      expect(responses).not_to be_nil

      expect(responses.row_count).to eq(4)
      expect(responses.row(0)).to eq(['Company/Group', 'Label', 'Responder', 'Email', 'Status', 'Rating', 'Invited', 'Opened', 'Submitted', 'Last Updated'])
      x = responses.row(1)
      expect(x[0]).to eq(@r1.user.company.name)
      expect(x[1]).to eq(@r1.subtitle)
      expect(x[2]).to eq(@r1.user.full_name)
      expect(x[3]).to eq(@r1.user.email)
      expect(x[4]).to eq(@r1.status)
      expect(x[5]).to eq(@r1.rating)
      expect(x[6].to_s).to eq(@r1.email_sent_date.to_s)
      expect(x[7].to_s).to eq(@r1.response_opened_date.to_s)
      expect(x[8].to_s).to eq(@r1.submitted_date.to_s)
      expect(x[9].to_s).to eq(@r1.updated_at.to_s)

      expect(responses.row(2)[1]).to eq(@r2.subtitle)

      questions = wb.worksheet "Questions"
      expect(questions).not_to be_nil

      expect(questions.row(0)).to eq(["Question", "Answered", "1", "2"])
      x = questions.row(1)
      expect(x[0]).to eq(@q1.content)
      expect(x[1]).to eq(1)
      expect(x[2]).to eq(1)
      expect(x[3]).to eq(1)

      x = questions.row(2)
      expect(x[0]).to eq(@q2.content)
      expect(x[1]).to eq(1)
      expect(x[2]).to eq(0)
      expect(x[3]).to eq(1)
    end
  end

  describe "save" do
    context "on survey with responses" do

      it "allows archiving" do
        survey = create(:survey, archived: false)
        allow(survey).to receive(:has_responses?).and_return true
        survey.update_attributes! archived: true
        survey.reload
        expect(survey.archived).to be_truthy
      end

      it "allows de-archiving" do
        survey = create(:survey, archived: true)

        allow(survey).to receive(:has_responses?).and_return true
        survey.update_attributes! archived: false
        survey.reload
        expect(survey.archived).to be_falsey
      end

      it "rejects if archived is not the only attribute being saved" do
        survey = Survey.new
        allow(survey).to receive(:has_responses?).and_return true

        expect(survey.update_attributes archived: false, name: "Blah").to be_falsey
        expect(survey.errors.full_messages).to eq ["You cannot change a locked survey."]
      end
    end
  end
end
