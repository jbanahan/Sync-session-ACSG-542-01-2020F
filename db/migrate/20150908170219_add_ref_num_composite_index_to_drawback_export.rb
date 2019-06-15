class AddRefNumCompositeIndexToDrawbackExport < ActiveRecord::Migration
  def change
    add_index :duty_calc_export_file_lines, [:ref_1,:ref_2,:ref_3,:ref_4,:part_number,:importer_id], {name: :unique_refs, length: {ref_1: 100, ref_2: 100, ref_3: 100, ref_4: 100, part_number: 100}}
  end
end
