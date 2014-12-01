class CreateSearchTemplates < ActiveRecord::Migration
  def change
    create_table :search_templates do |t|
      t.string :name
      t.string :module_type
      t.text :search_json
      t.timestamps
    end
  end
end
