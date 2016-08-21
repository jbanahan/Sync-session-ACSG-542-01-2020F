require 'spec_helper'

describe Answer do
  
  describe :log_update do
    it "should create survey_response_update" do
      answer = Factory(:answer)
      u = Factory(:user)
      answer.log_update u
      expect(answer.survey_response.survey_response_updates.first.user).to eq(u)
    end
  end
  describe :can_attach? do
    before :each do
      @a = Answer.new 
      @u = User.new
    end
    it "should allow if user can view" do
      expect(@a).to receive(:can_view?).with(@u).and_return true
      expect(@a.can_attach?(@u)).to be_truthy
    end
    it "should not allow if user cannot view" do
      expect(@a).to receive(:can_view?).with(@u).and_return false
      expect(@a.can_attach?(@u)).to be_falsey
    end
  end
  describe :answered? do
    it 'should not be answered as default' do
      expect(Factory(:answer)).not_to be_answered
    end
    it 'should be answered if choice is set' do
      expect(Factory(:answer,:choice=>'x')).to be_answered
    end
    it 'should be answered if comment assigned to survey response user is set' do
      a = Factory(:answer)
      a.answer_comments.create!(:user_id=>a.survey_response.user_id,:content=>'1234567890')
      expect(a).to be_answered
    end
    it 'should be answered if attachment assigned to survey response user is set' do
      a = Factory(:answer)
      a.attachments.create!(:uploaded_by_id=>a.survey_response.user_id)
      expect(a).to be_answered
    end
    it 'should not be answered if only comment is from a different user' do
      a = Factory(:answer)
      a.answer_comments.create!(:user_id=>Factory(:user).id,:content=>'1234567890')
      expect(a).not_to be_answered
    end
    it 'should not be answered if only attachment is from a different user' do
      a = Factory(:answer)
      a.attachments.create!(:uploaded_by_id=>Factory(:user).id)
      expect(a).not_to be_answered
    end
  end
  describe "can view" do
    before :each do
      @answer = Factory(:answer)
      @u = Factory(:user)
    end
    it "should pass if user can view survey response" do
      expect(@answer.survey_response).to receive(:can_view?).with(@u).and_return(true)
      expect(@answer.can_view?(@u)).to be_truthy
    end
    it "should fail if user cannot view survey response" do
      expect(@answer.survey_response).to receive(:can_view?).with(@u).and_return(false)
      expect(@answer.can_view?(@u)).to be_falsey
    end
  end
  it "should require survey_response" do
    a = Answer.new(:question=>Factory(:question))
    expect(a.save).to be_falsey
  end
  it "should require question" do
    a = Answer.new(:survey_response=>Factory(:survey_response))
    expect(a.save).to be_falsey
  end
  it "should accept nested attributes for comments" do
    a = Factory(:answer)
    u = Factory(:user)
    a.update_attributes(:answer_comments_attributes=>[{:user_id=>u.id,:content=>'abcdef'}])
    expect(AnswerComment.find_by_answer_id_and_user_id(a.id,u.id).content).to eq("abcdef")
  end
  it "should not accepted updates for comments via nested attributes" do
    a = Factory(:answer)
    u = Factory(:user)
    ac = a.answer_comments.create!(:user=>u,:content=>'abcdefg')
    a.update_attributes(:answer_comments_attributes=>[{:id=>ac.id,:content=>'xxx'}])
    expect(AnswerComment.find_by_answer_id_and_user_id(a.id,u.id).content).to eq("abcdefg")
  end
  it "should allow attachments" do
    a = Factory(:answer)
    a.attachments.create!(:attached_file_name=>"x.png")
  end
  it "should update parent response when answer is updated" do
    a = Factory(:answer)
    a.survey_response.update_attributes(:updated_at=>1.week.ago)
    a.choice = "X"
    now = Time.zone.now
    Timecop.freeze(now) do
      a.save!
    end

    expect(SurveyResponse.find(a.survey_response_id).updated_at.to_i).to eq now.to_i
  end

  describe "attachment_added" do
    it "updates updated_at when an attachment is added" do
      a = Factory(:answer, updated_at: 5.days.ago)
      now = Time.zone.now
      Timecop.freeze(now) do
        a.attachment_added nil
      end
      
      expect(a.updated_at.to_i).to eq(now.to_i)
    end
  end
end
