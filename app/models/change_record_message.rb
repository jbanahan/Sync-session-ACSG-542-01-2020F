# == Schema Information
#
# Table name: change_record_messages
#
#  change_record_id :integer
#  created_at       :datetime         not null
#  id               :integer          not null, primary key
#  message          :string(255)
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_change_record_messages_on_change_record_id  (change_record_id)
#

class ChangeRecordMessage < ActiveRecord::Base
  belongs_to :change_record
end
