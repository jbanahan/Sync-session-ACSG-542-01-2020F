class AddTrackingFieldsToCommercialInvoice < ActiveRecord::Migration
  def change
    add_column :commercial_invoices, :docs_received_date, :date
    add_column :commercial_invoices, :docs_ok_date, :date
    add_column :commercial_invoices, :issue_codes, :string
    add_column :commercial_invoices, :rater_comments, :text
  end
end
