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
