class AddFieldsToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :carrier_code, :string
    add_column :entries, :duty_due_date, :date
    add_column :entries, :total_packages, :integer
    add_column :entries, :total_fees, :decimal, :precision => 12, :scale => 2
    add_column :entries, :total_duty, :decimal, :precision => 12, :scale => 2
    add_column :entries, :total_duty_direct, :decimal, :precision => 12, :scale => 2
    add_column :entries, :total_entry_fee, :decimal, :precision => 11, :scale => 2
    add_column :entries, :entered_value, :decimal, :precision => 13, :scale => 2
    add_column :entries, :customer_references, :text
  end

  def self.down
    remove_column :entries, :customer_references
    remove_column :entries, :entered_value
    remove_column :entries, :total_entry_fee
    remove_column :entries, :total_duty_direct
    remove_column :entries, :total_duty
    remove_column :entries, :total_fees
    remove_column :entries, :total_packages
    remove_column :entries, :duty_due_date
    remove_column :entries, :carrier_code
  end
end
