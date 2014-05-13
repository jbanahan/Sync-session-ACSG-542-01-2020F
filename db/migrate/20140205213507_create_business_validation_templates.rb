class CreateBusinessValidationTemplates < ActiveRecord::Migration
  def change
    create_table :business_validation_templates do |t|
      t.string :name
      t.string :module_type, null: false
      t.string :description

      t.timestamps
    end
  end
end
