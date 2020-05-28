class AddInboundFileIdentifierIndexes < ActiveRecord::Migration
  def change
    add_index :inbound_file_identifiers, [:identifier_type, :value]
    add_index :inbound_file_identifiers, [:value]
    add_index :inbound_file_identifiers, [:module_type, :module_id]
    add_index :inbound_file_identifiers, [:module_id]
  end
end
