class CreateCustomValues < ActiveRecord::Migration
  def self.up
    create_table :custom_values do |t|
      t.integer :customizable_id
      t.string :customizable_type
      t.string :string_value
      t.decimal :decimal_value
      t.integer :integer_value
      t.date :date_value
      t.integer :custom_definition_id

      t.timestamps
    end
  end

  def self.down
    drop_table :custom_values
  end
end
