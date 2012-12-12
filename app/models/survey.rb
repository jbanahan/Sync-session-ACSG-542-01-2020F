class Survey < ActiveRecord::Base
  belongs_to :created_by, :class_name=>"User"
  belongs_to :company
  has_many :questions, :inverse_of=>:survey
  has_many :survey_responses, :inverse_of=>:survey
  has_many :assigned_users, :through=>:survey_responses, :source=>:user
  has_many :answers, :through=>:survey_responses
  has_many :survey_subscriptions, :dependent => :destroy
  
  validate :lock_check

  accepts_nested_attributes_for :questions, :allow_destroy => true,
    :reject_if => lambda {|q| q[:content].blank? && q[:_destroy].blank?}

  #copies and saves a new survey
  #only copies survey & questions; not subscribers, assigned users, or responses
  def copy!
    s = Survey.create!(:company_id=>self.company_id,:name=>self.name,:email_subject=>self.email_subject,:email_body=>self.email_body,:ratings_list=>self.ratings_list)
    self.questions.each do |q|
      s.questions.create!(:rank=>q.rank,:content=>q.content,:choices=>q.choices,:warning=>q.warning)
    end
    s
  end
  def locked?
    self.survey_responses.count!=0
  end
  
  def can_edit? user
    user.edit_surveys? && user.company_id == self.company_id
  end

  # get an array of potential values to be used when rating surveys
  def rating_values
    r = []
    self.ratings_list.lines {|x| r << x.strip unless x.blank?} unless self.ratings_list.blank?
    r
  end

  # generates a survey response in the target_user's account
  def generate_response! target_user, subtitle=nil
    sr = self.survey_responses.create!(:user=>target_user,:subtitle=>subtitle)
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
