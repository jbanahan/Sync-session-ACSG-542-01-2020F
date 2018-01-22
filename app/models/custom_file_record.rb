# == Schema Information
#
# Table name: custom_file_records
#
#  id                 :integer          not null, primary key
#  linked_object_type :string(255)
#  linked_object_id   :integer
#  custom_file_id     :integer
#  created_at         :datetime
#  updated_at         :datetime
#
# Indexes
#
#  cf_id           (custom_file_id)
#  linked_objects  (linked_object_id,linked_object_type)
#

class CustomFileRecord < ActiveRecord::Base
  belongs_to :custom_file
  belongs_to :linked_object, :polymorphic => true
end
