class AddPrivateToBusinessValidationTemplates < ActiveRecord::Migration
  def change
    add_column :business_validation_templates, :private, :boolean
  end
end
