# == Schema Information
#
# Table name: change_records
#
#  id                     :integer          not null, primary key
#  file_import_result_id  :integer
#  recordable_id          :integer
#  recordable_type        :string(255)
#  record_sequence_number :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  failed                 :boolean
#  bulk_process_log_id    :integer
#  unique_identifier      :string(255)
#
# Indexes
#
#  index_change_records_on_bulk_process_log_id    (bulk_process_log_id)
#  index_change_records_on_file_import_result_id  (file_import_result_id)
#

class ChangeRecord < ActiveRecord::Base
  belongs_to :file_import_result
  belongs_to :recordable, :polymorphic=>true
  has_many :change_record_messages, :dependent => :destroy
  belongs_to :bulk_process_log
  has_one :entity_snapshot

  # Build a chnage record message and optionally set the Change Record's failure flag to true (false will not turn the flag off)
  # Returns the ChangeRecordMessage that was built
  def add_message msg, set_failure_flag = false
    self.failed = true if set_failure_flag
    self.change_record_messages.build(:message=>msg)
  end

  # Return collection of all message bodies
  def messages
    self.change_record_messages.collect {|m| m.message} 
  end
end
