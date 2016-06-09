class AddModuleTypeToCustomViewTemplates < ActiveRecord::Migration
  def up
    add_column :custom_view_templates, :module_type, :string
    execute "UPDATE custom_view_templates SET module_type = 'Order' WHERE module_type IS NULL"
  end

  def down
    remove_column :custom_view_templates, :module_type
  end
end
