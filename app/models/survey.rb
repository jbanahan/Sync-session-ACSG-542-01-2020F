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
    has_responses? || archived?
  end
  
  def can_edit? user
    user.edit_surveys? && user.company_id == self.company_id
  end

  def can_view? user
    self.can_edit?(user)
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

  def to_xls 
    wb = Spreadsheet::Workbook.new
    create_responses_sheet wb
    create_questions_sheet wb
    wb
  end
  
  private

  def has_responses?
    self.survey_responses.count!=0
  end

  def lock_check
    # Allow changing archived flag if, as long as that's all that's being changed
    if has_responses?
      changed_fields = changed
      if changed_fields.first == "archived" && changed_fields.length == 1
        return true
      else
        errors[:base] << "You cannot change a locked survey."
      end
    end
  end

  def create_responses_sheet workbook
    sheet = workbook.create_worksheet :name=>"Survey Responses"

    row = 0
    cols = ['Company', 'Label', 'Responder', 'Status', 'Rating', 'Invited', 'Opened', 'Submitted', 'Last Updated']
    col_widths = []
    XlsMaker.add_header_row sheet, row, cols, col_widths
    row += 1

    self.survey_responses.was_archived(false).each do |r|
      cols = []
      cols << r.user.company.name
      cols << r.subtitle
      cols << r.user.full_name
      cols << r.status
      cols << r.rating
      cols << r.email_sent_date
      cols << r.response_opened_date
      cols << r.submitted_date
      cols << r.updated_at

      XlsMaker.add_body_row sheet, row, cols, col_widths, true
      row += 1
    end
  end

  def create_questions_sheet workbook
    sheet = workbook.create_worksheet :name => "Questions"
    
    row = 0
    cols = ['Question', 'Answered']
    self.rating_values.each do |value|
      cols << value
    end
    col_widths = []

    XlsMaker.add_header_row sheet, row, cols, col_widths
    row += 1

    wrap_format = Spreadsheet::Format.new :text_wrap => true
    self.questions.each do |q|
      cols = []
      
      # The question content is actually textile markup, which is converted to HTML when viewed
      # by the browser.  Excel doesn't support that, so we're just displaying the raw text.
      cols << q.content
      cols << self.answers.where(:question_id=>q.id).where("survey_responses.submitted_date is not null").merge(SurveyResponse.was_archived(false)).count
      self.rating_values.each do |value|
        # This may be a bug, we're limiting answer counts only for 
        cols << self.answers.where(:question_id=>q.id, :rating=>value).merge(SurveyResponse.was_archived(false)).count
      end
      
      XlsMaker.add_body_row sheet, row, cols, col_widths, true
      # Make sure the content column allows text wrap
      sheet.row(row).set_format(0, wrap_format)
      row += 1
    end
  end
end
