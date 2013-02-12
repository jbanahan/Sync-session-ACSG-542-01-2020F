class AddS3InfoToBrokerInvoice < ActiveRecord::Migration
  def change
    add_column :broker_invoices, :last_file_bucket, :string
    add_column :broker_invoices, :last_file_path, :string
  end
end
