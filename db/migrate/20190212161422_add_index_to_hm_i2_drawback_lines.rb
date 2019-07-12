class AddIndexToHmI2DrawbackLines < ActiveRecord::Migration
  def up
    add_index :hm_i2_drawback_lines, [:invoice_number, :po_number, :part_number], name: "index_hm_i2_drawback_lines_on_inv_num_po_num_and_part_num"
  end

  def down
    remove_index :hm_i2_drawback_lines, :name=>'index_hm_i2_drawback_lines_on_inv_num_po_num_and_part_num'
  end
end