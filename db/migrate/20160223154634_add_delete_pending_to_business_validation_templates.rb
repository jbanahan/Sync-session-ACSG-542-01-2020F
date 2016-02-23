class AddDeletePendingToBusinessValidationTemplates < ActiveRecord::Migration
  def up
    add_column :business_validation_templates, :delete_pending, :boolean
  end

  def down
    remove_column :business_validation_templates, :delete_pending
  end
end
