class AddDisabledToBusinessValidationTemplates < ActiveRecord::Migration
  def change
    add_column :business_validation_templates, :disabled, :boolean
  end
end
