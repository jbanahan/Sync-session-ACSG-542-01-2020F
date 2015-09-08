class AddRefNumCompositeIndexToDrawbackExport < ActiveRecord::Migration
  def change
    add_index :duty_calc_export_file_lines, [:ref_1,:ref_2,:ref_3,:ref_4,:part_number,:importer_id], {name: :unique_refs}
  end
end
