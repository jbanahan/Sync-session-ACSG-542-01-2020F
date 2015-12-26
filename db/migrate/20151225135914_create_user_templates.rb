class CreateUserTemplates < ActiveRecord::Migration
  def change
    create_table :user_templates do |t|
      t.string :name
      t.text :template_json

      t.timestamps
    end
  end
end
