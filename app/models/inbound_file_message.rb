# == Schema Information
#
# Table name: inbound_file_messages
#
#  id              :integer          not null, primary key
#  inbound_file_id :integer
#  message         :text(65535)
#  message_status  :string(255)
#
# Indexes
#
#  index_inbound_file_messages_on_inbound_file_id  (inbound_file_id)
#

class InboundFileMessage < ActiveRecord::Base
  belongs_to :inbound_file, inverse_of: :messages

  MESSAGE_STATUS_INFO = "Info"
  MESSAGE_STATUS_WARNING = "Warning"
  MESSAGE_STATUS_REJECT = "Reject"
  MESSAGE_STATUS_ERROR = "Error"

  MESSAGE_STATUSES = [MESSAGE_STATUS_INFO, MESSAGE_STATUS_WARNING, MESSAGE_STATUS_REJECT, MESSAGE_STATUS_ERROR]
end
