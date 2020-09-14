class AddSetBlankToImportedFiles < ActiveRecord::Migration
  def change
    change_table :imported_files do |t|
      t.column :set_blank, :boolean, default: false
    end
  end
end
