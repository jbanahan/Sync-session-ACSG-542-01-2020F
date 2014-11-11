class AddTrackingInfoToIntacctAllianceExport < ActiveRecord::Migration
  def up
    change_table :intacct_alliance_exports do |t|
      t.string :division
      t.string :customer_number
      t.date :invoice_date
      t.string :check_number
      t.decimal :ap_total, precision: 10, scale: 2
      t.decimal :ar_total, precision: 10, scale: 2
      t.string :export_type
    end
  end

  def down
    change_table :intacct_alliance_exports do |t|
      t.remove :division
      t.remove :customer_number
      t.remove :invoice_date
      t.remove :check_number
      t.remove :ap_total
      t.remove :ar_total
      t.remove :export_type
    end
  end
end