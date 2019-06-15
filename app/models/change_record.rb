# == Schema Information
#
# Table name: change_records
#
#  bulk_process_log_id    :integer
#  created_at             :datetime         not null
#  failed                 :boolean
#  file_import_result_id  :integer
#  id                     :integer          not null, primary key
#  record_sequence_number :integer
#  recordable_id          :integer
#  recordable_type        :string(255)
#  unique_identifier      :string(255)
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_change_records_on_bulk_process_log_id    (bulk_process_log_id)
#  index_change_records_on_file_import_result_id  (file_import_result_id)
#

class ChangeRecord < ActiveRecord::Base
  attr_accessible :bulk_process_log_id, :failed, :file_import_result_id,
    :record_sequence_number, :recordable_id, :recordable, :recordable_type, 
    :unique_identifier, :entity_snapshot

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
