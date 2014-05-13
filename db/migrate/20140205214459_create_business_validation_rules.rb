class CreateBusinessValidationRules < ActiveRecord::Migration
  def change
    create_table :business_validation_rules do |t|
      t.references :business_validation_template
      t.string :type
      t.string :name
      t.string :description
      t.string :fail_state
      t.text :rule_attributes_json
      t.timestamps
    end
    add_index :business_validation_rules, :business_validation_template_id, {name: 'template_id'}
  end
end
