class AddRowCountsToFileImportResult < ActiveRecord::Migration
  def self.up
    add_column :file_import_results, :expected_rows, :integer
    add_column :file_import_results, :rows_processed, :integer
  end

  def self.down
    remove_column :file_import_results, :rows_processed
    remove_column :file_import_results, :expected_rows
  end
end
