class AddCdefUidToCustomdefinition < ActiveRecord::Migration
  def change
    add_column :custom_definitions, :cdef_uid, :string
    add_index :custom_definitions, :cdef_uid
  end
end
