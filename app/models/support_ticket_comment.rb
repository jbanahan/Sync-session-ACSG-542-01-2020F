class SupportTicketComment < ActiveRecord::Base
  belongs_to :support_ticket, :inverse_of=>:support_ticket_comments
  belongs_to :user
  has_many :attachments, :as=>:attachable, :dependent=>:destroy

  accepts_nested_attributes_for :attachments, :reject_if => lambda {|q|
    q[:attached].blank?
  }
end
