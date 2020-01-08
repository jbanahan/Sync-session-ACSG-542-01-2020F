class AddIndexesToInboundFileIdentifierAndMessages < ActiveRecord::Migration
  def change
    # add_index is reversible automatically by rails (so this can just be in a change method)
    add_index :inbound_file_messages, :inbound_file_id
    add_index :inbound_file_identifiers, :inbound_file_id
  end
end
