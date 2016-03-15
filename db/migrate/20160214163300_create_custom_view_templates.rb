class CreateCustomViewTemplates < ActiveRecord::Migration
  def change
    create_table :custom_view_templates do |t|
      t.string :template_identifier
      t.string :template_path

      t.timestamps
    end
    add_index :custom_view_templates, :template_identifier
  end
end
