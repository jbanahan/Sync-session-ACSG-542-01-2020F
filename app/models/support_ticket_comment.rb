class SupportTicketComment < ActiveRecord::Base
  belongs_to :support_ticket, :inverse_of=>:support_ticket_comments
  has_many :attachments, :as=>:attachable, :dependent=>:destroy
end
