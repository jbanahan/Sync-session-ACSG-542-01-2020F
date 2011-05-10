class CreateFieldValidatorRules < ActiveRecord::Migration
  def self.up
    create_table :field_validator_rules do |t|
      t.string :model_field_uid
      t.string :module_type
      t.decimal :greater_than
      t.decimal :less_than
      t.integer :greater_than_ago
      t.integer :less_than_ago
      t.string :greater_than_ago_uom
      t.string :less_than_ago_uom
      t.date :greater_than_date
      t.date :less_than_date
      t.string :regex
      t.text :comment
      t.string :custom_message
      t.boolean :required
      t.string :starts_with
      t.string :ends_with
      t.string :contains
      t.text :one_of

      t.timestamps
    end
  end

  def self.down
    drop_table :field_validator_rules
  end
end
