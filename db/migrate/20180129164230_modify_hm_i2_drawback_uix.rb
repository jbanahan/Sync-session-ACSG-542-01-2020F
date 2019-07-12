class ModifyHmI2DrawbackUix < ActiveRecord::Migration
  def up
    remove_index :hm_i2_drawback_lines, name: "index_hm_i2_drawback_lines_on_invoice_and_line_number"
    add_index :hm_i2_drawback_lines, [:invoice_number, :invoice_line_number, :shipment_type], unique: true, name: "index_hm_i2_drawback_lines_on_inv_num_line_num_and_type"
  end

  def down
    # No need to roll back.
  end
end