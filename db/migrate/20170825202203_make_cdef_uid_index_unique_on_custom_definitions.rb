class MakeCdefUidIndexUniqueOnCustomDefinitions < ActiveRecord::Migration
  def change
    remove_index :custom_definitions, :cdef_uid
    add_index :custom_definitions, :cdef_uid, unique: true
  end

  def down
    remove_index :custom_definitions, :cdef_uid
    add_index :custom_definitions, :cdef_uid
  end
end
