class AddConvertedDateToHmReceiptLines < ActiveRecord::Migration
  def up
    change_table :hm_receipt_lines, bulk:true do |t|
      t.datetime :converted_date
    end
  end

  def down
    remove_column :hm_receipt_lines, :converted_date
  end
end