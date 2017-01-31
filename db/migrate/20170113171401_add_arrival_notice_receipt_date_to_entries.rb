class AddArrivalNoticeReceiptDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :arrival_notice_receipt_date, :datetime
  end
end
