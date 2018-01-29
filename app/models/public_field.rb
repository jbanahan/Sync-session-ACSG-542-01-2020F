# == Schema Information
#
# Table name: public_fields
#
#  id              :integer          not null, primary key
#  model_field_uid :string(255)
#  searchable      :boolean
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_public_fields_on_model_field_uid  (model_field_uid)
#

class PublicField < ActiveRecord::Base

  after_save :reload_model_fields

private
  def reload_model_fields
    ModelField.reload true #update flag in cache so other threads reload their model fields
  end

end
