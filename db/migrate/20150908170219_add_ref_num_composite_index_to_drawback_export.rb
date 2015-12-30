class AddRefNumCompositeIndexToDrawbackExport < ActiveRecord::Migration
  def change
    # The default charset in CircleCI is different than our production server, so the key lengths on the index is too long in Circle
    # Just work around that by using only part of the column for the index
    if ENV["CIRCLECI"] || File.exist?('.c9/project.settings')
      execute "CREATE INDEX unique_refs ON duty_calc_export_file_lines(ref_1(100), ref_2(100), ref_3(100), ref_4(100), part_number(100), importer_id)"
    else
      add_index :duty_calc_export_file_lines, [:ref_1,:ref_2,:ref_3,:ref_4,:part_number,:importer_id], {name: :unique_refs}
    end
  end
end
