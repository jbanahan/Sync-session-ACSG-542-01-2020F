class AddLiquidationToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :liquidation_type_code, :string
    add_column :entries, :liquidation_type, :string
    add_column :entries, :liquidation_action_code, :string
    add_column :entries, :liquidation_action_description, :string
    add_column :entries, :liquidation_extension_code, :string
    add_column :entries, :liquidation_extension_description, :string
    add_column :entries, :liquidation_extension_count, :integer
    add_column :entries, :liquidation_duty, :decimal, :precision=>12, :scale=>2 
    add_column :entries, :liquidation_fees, :decimal, :precision=>12, :scale=>2 
    add_column :entries, :liquidation_tax, :decimal, :precision=>12, :scale=>2 
    add_column :entries, :liquidation_ada, :decimal, :precision=>12, :scale=>2 
    add_column :entries, :liquidation_cvd, :decimal, :precision=>12, :scale=>2
    add_column :entries, :liquidation_total, :decimal, :precision=>12, :scale=>2
  end

  def self.down
    remove_column :entries, :liquidation_duty
    remove_column :entries, :liquidation_fees
    remove_column :entries, :liquidation_tax
    remove_column :entries, :liquidation_ada
    remove_column :entries, :liquidation_cvd
    remove_column :entries, :liquidation_total
    remove_column :entries, :liquidation_extension_count
    remove_column :entries, :liquidation_extension_description
    remove_column :entries, :liquidation_extension_code
    remove_column :entries, :liquidation_action_description
    remove_column :entries, :liquidation_action_code
    remove_column :entries, :liquidation_type
    remove_column :entries, :liquidation_type_code
  end
end
