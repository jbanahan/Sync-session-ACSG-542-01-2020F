class AddModuleTypeToCustomViewTemplates < ActiveRecord::Migration
  def up
    add_column :custom_view_templates, :module_type, :string
  end

  def down
    remove_column :custom_view_templates, :module_type
  end
end
