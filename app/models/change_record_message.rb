# == Schema Information
#
# Table name: change_record_messages
#
#  id               :integer          not null, primary key
#  change_record_id :integer
#  message          :string(255)
#  created_at       :datetime
#  updated_at       :datetime
#
# Indexes
#
#  index_change_record_messages_on_change_record_id  (change_record_id)
#

class ChangeRecordMessage < ActiveRecord::Base
  belongs_to :change_record
end
