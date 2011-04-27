class ChangeRecord < ActiveRecord::Base
  belongs_to :file_import_result
  belongs_to :recordable, :polymorphic=>true
end
