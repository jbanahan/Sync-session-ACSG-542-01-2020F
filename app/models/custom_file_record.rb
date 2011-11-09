class CustomFileRecord < ActiveRecord::Base
  belongs_to :custom_file
  belongs_to :linked_object, :polymorphic => true
end
