class ChangeRecord < ActiveRecord::Base
  belongs_to :file_import_result
  belongs_to :recordable, :polymorphic=>true
  has_many :change_record_messages, :dependent => :destroy
end
