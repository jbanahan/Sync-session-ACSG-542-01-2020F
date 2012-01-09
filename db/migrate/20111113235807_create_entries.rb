class CreateEntries < ActiveRecord::Migration
  def self.up
    create_table :entries do |t|
      t.string :broker_reference
      t.string :entry_number
      t.datetime :last_exported_from_source
      t.string :company_number
      t.string :division_number
      t.string :customer_number
      t.string :customer_name
      t.string :entry_type
      t.datetime :arrival_date
      t.datetime :entry_filed_date
      t.datetime :release_date
      t.datetime :first_release_date
      t.datetime :free_date
      t.datetime :last_billed_date
      t.datetime :invoice_paid_date
      t.datetime :liquidation_date

      t.timestamps
    end
    add_index :entries, :customer_number
    add_index :entries, :broker_reference
    add_index :entries, :entry_number
    add_index :entries, :division_number
  end

  def self.down
    drop_table :entries
  end
end
