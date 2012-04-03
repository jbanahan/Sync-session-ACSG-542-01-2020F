class Survey < ActiveRecord::Base
  belongs_to :created_by, :class_name=>"User"
  belongs_to :company
  has_many :questions, :inverse_of=>:survey
  has_many :survey_responses, :inverse_of=>:survey
  has_many :assigned_users, :through=>:survey_responses, :source=>:user
  has_many :answers, :through=>:survey_responses
  
  validate :lock_check

  accepts_nested_attributes_for :questions, :allow_destroy => true,
    :reject_if => lambda {|q| q[:content].blank? && q[:_destroy].blank?}

  def locked?
    self.survey_responses.count!=0
  end
  
  def can_edit? user
    user.edit_surveys? && user.company_id == self.company_id
  end

  # generates a survey response in the target_user's account
  def generate_response! target_user
    sr = self.survey_responses.create!(:user=>target_user)
    self.questions.each do |q|
      sr.answers.create!(:question=>q)
    end
    sr.survey_response_logs.create(:message=>"Survey assigned to #{target_user.full_name}")
    sr
  end

  private
  def lock_check
    errors[:base] << "You cannot change a locked survey." if self.locked?
  end
end
