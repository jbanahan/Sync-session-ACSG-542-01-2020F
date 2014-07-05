class CreateDrawbackExportHistories < ActiveRecord::Migration
  def change
    create_table :drawback_export_histories do |t|
      t.string :part_number
      t.string :export_ref_1
      t.date :export_date
      t.decimal :quantity, :precision => 13, :scale => 4
      t.decimal :claim_amount_per_unit, :precision => 13, :scale => 4
      t.decimal :claim_amount, :precision => 13, :scale => 4
      t.integer :drawback_claim_id

      t.timestamps
    end
    add_index :drawback_export_histories, [:drawback_claim_id]
    add_index :drawback_export_histories, [:part_number,:export_ref_1,:export_date], {:name=>:export_idx} 
  end
end
