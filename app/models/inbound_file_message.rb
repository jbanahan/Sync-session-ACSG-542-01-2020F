# == Schema Information
#
# Table name: inbound_file_messages
#
#  id              :integer          not null, primary key
#  inbound_file_id :integer
#  message         :text
#  message_status  :string(255)
#

class InboundFileMessage < ActiveRecord::Base
  attr_accessible :inbound_file_id, :message, :message_status
  
  belongs_to :inbound_file, inverse_of: :messages

  MESSAGE_STATUS_INFO = "Info"
  MESSAGE_STATUS_WARNING = "Warning"
  MESSAGE_STATUS_REJECT = "Reject"
  MESSAGE_STATUS_ERROR = "Error"

  MESSAGE_STATUSES = [MESSAGE_STATUS_INFO, MESSAGE_STATUS_WARNING, MESSAGE_STATUS_REJECT, MESSAGE_STATUS_ERROR]
end
