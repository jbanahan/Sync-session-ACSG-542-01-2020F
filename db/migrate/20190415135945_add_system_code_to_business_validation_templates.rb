class AddSystemCodeToBusinessValidationTemplates < ActiveRecord::Migration
  def change
    add_column :business_validation_templates, :system_code, :string
  end
end
