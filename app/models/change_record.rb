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
