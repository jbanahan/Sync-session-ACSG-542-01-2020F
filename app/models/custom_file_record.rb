# == Schema Information
#
# Table name: custom_file_records
#
#  created_at         :datetime         not null
#  custom_file_id     :integer
#  id                 :integer          not null, primary key
#  linked_object_id   :integer
#  linked_object_type :string(255)
#  updated_at         :datetime         not null
#
# Indexes
#
#  cf_id           (custom_file_id)
#  linked_objects  (linked_object_id,linked_object_type)
#

class CustomFileRecord < ActiveRecord::Base
  attr_accessible :custom_file_id, :linked_object_id, :linked_object_type

  belongs_to :custom_file
  belongs_to :linked_object, :polymorphic => true
end
