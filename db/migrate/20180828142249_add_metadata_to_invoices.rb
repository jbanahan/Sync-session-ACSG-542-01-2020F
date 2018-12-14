class AddMetadataToInvoices < ActiveRecord::Migration
  def up
    change_table(:invoices, bulk: true) do |t|
      t.datetime :last_exported_from_source
      t.string :last_file_bucket
      t.string :last_file_path
    end
  end

  def down
    change_table(:invoices, bulk: true) do |t|
      t.remove :last_exported_from_source
      t.remove :last_file_bucket
      t.remove :last_file_path
    end
  end
end
