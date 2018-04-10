# == Schema Information
#
# Table name: search_columns
#
#  created_at           :datetime         not null
#  custom_definition_id :integer
#  custom_report_id     :integer
#  id                   :integer          not null, primary key
#  imported_file_id     :integer
#  model_field_uid      :string(255)
#  rank                 :integer
#  search_setup_id      :integer
#  updated_at           :datetime         not null
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
