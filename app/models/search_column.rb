# == Schema Information
#
# Table name: search_columns
#
#  id                   :integer          not null, primary key
#  search_setup_id      :integer
#  rank                 :integer
#  model_field_uid      :string(255)
#  custom_definition_id :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  imported_file_id     :integer
#  custom_report_id     :integer
#
# Indexes
#
#  index_search_columns_on_custom_report_id  (custom_report_id)
#  index_search_columns_on_imported_file_id  (imported_file_id)
#  index_search_columns_on_search_setup_id   (search_setup_id)
#

class SearchColumn < ActiveRecord::Base
  include HoldsCustomDefinition
  belongs_to :search_setup
  belongs_to :imported_file

  # can this values in this column be used to find the appropriate unique object in the database
  def key_column?
    mf = model_field
    if mf.core_module #blank won't have core module
      mf.core_module.key_model_field_uids.include? mf.uid
    else
      false
    end
  end
end
