class SupportTicket < ActiveRecord::Base
  belongs_to :requestor, :class_name => "User"
  belongs_to :agent, :class_name => "User"
  belongs_to :last_saved_by, :class_name => "User"
  has_many :support_ticket_comments, :dependent=>:destroy
  has_many :attachments, :as=>:attachable, :dependent=>:destroy
  after_save :send_notification_callback
  validates_presence_of :requestor
  validates :subject, :length=>{:minimum=>10,:too_short=>"Short description must be at least 10 characters."}

  accepts_nested_attributes_for :support_ticket_comments, :reject_if => lambda { |q|
    ( q[:body].blank? && ( q[:attachments].blank? || q[:attachments][:attached].blank? ) ) || q[:user_id].blank? 
  }
  accepts_nested_attributes_for :attachments, :reject_if => lambda {|q|
    q[:attached].blank?
  }

  scope :open, where(" NOT state <=> ? ","closed")
  
  def can_view? user
    self.requestor == user || user.admin? || user.support_agent? || user.sys_admin?
  end

  def can_edit? user
    can_view?(user)
  end

  #send notification email to appropriate party based on last_saved_by
  def send_notification
    return if self.last_saved_by.nil?
    if self.requestor == self.last_saved_by  
      OpenMailer.send_support_ticket_to_agent(self).deliver
    elsif self.agent == self.last_saved_by
      OpenMailer.send_support_ticket_to_requestor(self).deliver if self.email_notifications?
    else
      OpenMailer.send_support_ticket_to_agent(self).deliver
      OpenMailer.send_support_ticket_to_requestor(self).deliver if self.email_notifications?
    end
  end

  private
  def send_notification_callback
    self.delay.send_notification if self.last_saved_by
  end
end
