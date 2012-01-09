class AddFieldsForShoesProjectToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :container_numbers, :text
    add_column :entries, :container_sizes, :string
    add_column :entries, :fcl_lcl, :string
    add_column :entries, :lading_port_code, :string
    add_column :entries, :consignee_address_1, :string
    add_column :entries, :consignee_address_2, :string
    add_column :entries, :consignee_city, :string
    add_column :entries, :consignee_state, :string
    add_column :entries, :unlading_port_code, :string
  end

  def self.down
    remove_column :entries, :unlading_port_code
    remove_column :entries, :consignee_state
    remove_column :entries, :consignee_city
    remove_column :entries, :consignee_address_2
    remove_column :entries, :consignee_address_1
    remove_column :entries, :lading_port_code
    remove_column :entries, :fcl_lcl
    remove_column :entries, :container_sizes
    remove_column :entries, :container_numbers
  end
end
