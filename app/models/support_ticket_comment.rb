# == Schema Information
#
# Table name: support_ticket_comments
#
#  id                :integer          not null, primary key
#  support_ticket_id :integer
#  user_id           :integer
#  body              :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_support_ticket_comments_on_support_ticket_id  (support_ticket_id)
#

class SupportTicketComment < ActiveRecord::Base
  belongs_to :support_ticket, :inverse_of=>:support_ticket_comments
  belongs_to :user
  has_many :attachments, :as=>:attachable, :dependent=>:destroy

  accepts_nested_attributes_for :attachments, :reject_if => lambda {|q|
    q[:attached].blank?
  }

  def can_view? user
    !self.support_ticket.nil? && self.support_ticket.can_view?(user)
  end
end
