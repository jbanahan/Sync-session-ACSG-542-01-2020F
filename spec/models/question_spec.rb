describe Question do
  it 'should default sort by rank' do
    q2 = create(:question, :rank=>2)
    q1 = create(:question, :rank=>1)
    expect(Question.by_rank.to_a).to eq([q1, q2])
  end
  it "should touch parent survey" do
    q = create(:question)
    s = q.survey
    s.update_attributes(:updated_at=>1.day.ago)
    expect(Survey.find(s.id).updated_at).to be < 23.hours.ago
    q.update_attributes(:content=>'123456489121351')
    expect(Survey.find(s.id).updated_at).to be > 1.minute.ago
  end
  it "should not save if parent survey is locked" do
    s = create(:survey)
    q = create(:question, :survey=>s)
    allow_any_instance_of(Survey).to receive(:locked?).and_return(:true)
    q.content = 'some content length'
    expect(q.save).to be_falsey
    expect(q.errors.full_messages.first).to eq("Cannot save question because survey is missing or locked.")
  end
  it "should require parent survey" do
    q = Question.new(:content=>'abc')
    expect(q.save).to be_falsey
  end
  it "should require content" do
    s = create(:survey)
    q = Question.new(:survey_id=>s.id)
    expect(q.save).to be_falsey
  end
  it "should default scope to sort by rank then id" do
    s = create(:survey)
    q_10 = s.questions.create!(:content=>"1234567890", :rank=>10)
    q_1 = s.questions.create!(:content=>"12345647879", :rank=>1)
    q_1_2 = s.questions.create!(:content=>"12345678901", :rank=>1)
    sorted = Survey.find(s.id).questions.to_a
    expect(sorted[0]).to eq(q_1)
    expect(sorted[1]).to eq(q_1_2)
    expect(sorted[2]).to eq(q_10)
  end
  it 'should allow one or more attachments' do
    s = create(:survey)
    q = Question.new(survey_id: s.id, content: "Sample content of a question.")
    q.save!
    q.attachments.create!(attached_file_name:"attachment1.jpg")
    q.attachments.create!(attached_file_name:"attachment2.jpg")
    expect(q.attachments.length).to eq(2)
  end
  it 'should not allow downloads if user does not have permission' do
    u = User.new
    s = create(:survey)
    q = Question.new(survey_id: s.id, content: "Sample content of a question.")
    q.save!
    expect(q.can_view?(u)).to be_falsey
  end
  it 'should allow downloads for creator of the survey' do
    ## In this case, the user in question is the survey creator
    user = create(:user, survey_edit: true)
    survey = create(:survey, created_by_id: user.id, company_id: user.company_id)
    question = Question.new(survey_id: survey.id, content: "Sample content of a question.")
    expect(question.can_view?(user)).to be_truthy
  end
  it 'should allow downloads for viewers of the response' do
    ## In this case, the user in question is a viewer of the survey response
    user = create(:user)
    survey = create(:survey, created_by_id: user.id)
    question = Question.new(survey_id: survey.id, content: "Sample content of a question.")
    survey_response = create(:survey_response, survey: survey, user_id: user.id)
    expect(question.can_view?(user)).to be_truthy
  end
end
