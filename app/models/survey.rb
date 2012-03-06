class Survey < ActiveRecord::Base
  belongs_to :created_by, :class_name=>"User"
  belongs_to :company
  has_many :questions, :inverse_of=>:survey
  has_many :survey_responses, :inverse_of=>:survey
  
  validate :lock_check

  accepts_nested_attributes_for :questions, :allow_destroy => true,
    :reject_if => lambda {|q| q[:content].blank? && q[:_destroy].blank?}

  def locked?
    self.survey_responses.count!=0
  end

  # generates a survey response in the target_user's account
  def generate_response! target_user
    sr = self.survey_responses.create!(:user=>target_user)
    self.questions.each do |q|
      sr.answers.create!(:question=>q)
    end
    sr
  end

  private
  def lock_check
    errors[:base] << "You cannot change a locked survey." if self.locked?
  end
end
