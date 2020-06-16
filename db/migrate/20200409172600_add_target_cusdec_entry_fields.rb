class AddTargetCusdecEntryFields < ActiveRecord::Migration
  def up
    change_table(:entries, bulk: true) do |t|
      t.datetime :summary_accepted_date
      t.string :bond_surety_number
    end
    change_table(:commercial_invoices, bulk: true) do |t|
      t.string :customer_reference
    end
    change_table(:commercial_invoice_lines, bulk: true) do |t|
      t.string :ruling_number
      t.string :ruling_type
      t.decimal :hmf_rate, precision: 14, scale: 8
      t.decimal :mpf_rate, precision: 14, scale: 8
      t.decimal :cotton_fee_rate, precision: 14, scale: 8
    end
  end

  def down
    change_table(:entries, bulk: true) do |t|
      t.remove :summary_accepted_date
      t.remove :bond_surety_number
    end
    change_table(:commercial_invoices, bulk: true) do |t|
      t.remove :customer_reference
    end
    change_table(:commercial_invoice_lines, bulk: true) do |t|
      t.remove :ruling_number
      t.remove :ruling_type
      t.remove :hmf_rate
      t.remove :mpf_rate
      t.remove :cotton_fee_rate
    end
  end
end
