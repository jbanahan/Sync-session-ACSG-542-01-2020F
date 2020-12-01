describe AnswerComment do
  it "should require answer" do
    c = AnswerComment.new(:user=>FactoryBot(:user), :content=>'abc')
    expect(c.save).to be_falsey
  end
  it "should require user" do
    expect(AnswerComment.new(:answer=>FactoryBot(:answer), :content=>'abc').save).to be_falsey
  end
  it "should require content" do
    expect(AnswerComment.new(:user=>FactoryBot(:user), :answer=>FactoryBot(:answer)).save).to be_falsey
  end
  it "should save with all requirements" do
    expect(AnswerComment.new(:user=>FactoryBot(:user), :answer=>FactoryBot(:answer), :content=>'abc').save).to be_truthy
  end
  it "should update answer and response updated_at" do
    a = FactoryBot(:answer)
    ac = a.answer_comments.create!(:user=>FactoryBot(:user), :content=>'1239014')
    update = 10.seconds.ago
    a.update_column :updated_at, update
    a.survey_response.update_column :updated_at, update

    ac.content = '191985'
    ac.save!
    a.reload
    expect(a.updated_at).to be > update
    expect(a.survey_response.updated_at).to be > update
  end
end
