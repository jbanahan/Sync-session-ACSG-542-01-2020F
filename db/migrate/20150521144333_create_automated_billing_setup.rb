class CreateAutomatedBillingSetup < ActiveRecord::Migration
  def up
    create_table :automated_billing_setups do |t|
      t.string :customer_number
      t.boolean :enabled

      t.timestamps
    end

    add_index :automated_billing_setups, :customer_number
    add_column :search_criterions, :automated_billing_setup_id, :integer
    add_index :search_criterions, :automated_billing_setup_id
  end

  def down
    drop_table :automated_billing_setups
    remove_column :search_criterions, :automated_billing_setup_id
  end
end
