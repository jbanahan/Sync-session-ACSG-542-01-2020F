# == Schema Information
#
# Table name: search_columns
#
#  constant_field_name  :string(255)
#  constant_field_value :string(255)
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

  attr_accessible :constant_field_name, :constant_field_value,
    :custom_definition_id, :custom_report_id, :imported_file_id,
    :model_field_uid, :rank, :search_setup_id

  belongs_to :search_setup
  belongs_to :imported_file

  # can this values in this column be used to find the appropriate unique object in the database
  def key_column?
    mf = model_field
    if mf.core_module # blank won't have core module
      mf.core_module.key_model_field_uids.include? mf.uid
    else
      false
    end
  end

  # When SearchColumn's MF is a constant, its model_field_uid refers to the temporary uid assigned by the front-end.
  # The real model_field_uid is generated dynamically below. Assigning an actual constant MF uid will set off
  # an infinite recursion (see HoldsCustomDefinition#model_field_uid= )

  def model_field
    if model_field_uid.match(/^_const/)
      assemble_constant_field
    else
      super
    end
  end

  private

  def assemble_constant_field
    cm = CoreModule.find_by_class_name(search_setup.try(:module_type) || imported_file.try(:module_type))
    rank = ModelField.next_index_number cm
    opts = {read_only: true, label_override: constant_field_name, export_lambda: constant_export_lambda, import_lambda: constant_import_lambda, qualified_field_name: constant_qualified_field_name}
    mf = ModelField.new rank, "*const_#{id}", cm, nil, opts
    mf.define_singleton_method(:blank?) { true } if constant_field_value.blank?
    mf
  end

  def constant_export_lambda
    lambda { |obj| self.constant_field_value }
  end

  def constant_import_lambda
    lambda { |obj, data| "Constant Field ignored. (read only)" }
  end

  def constant_qualified_field_name
    "(SELECT #{ActiveRecord::Base.connection.quote(constant_field_value)})"
  end

end
