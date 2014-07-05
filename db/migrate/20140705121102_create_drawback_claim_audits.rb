class CreateDrawbackClaimAudits < ActiveRecord::Migration
  def change
    create_table :drawback_claim_audits do |t|
      t.string :export_part_number
      t.string :export_ref_1
      t.date :export_date
      t.string :import_part_number
      t.string :import_ref_1
      t.date :import_date
      t.string :import_entry_number
      t.decimal :quantity, :precision => 13, :scale => 4
      t.integer :drawback_claim_id

      t.timestamps
    end
    add_index :drawback_claim_audits, [:drawback_claim_id]
    add_index :drawback_claim_audits, [:export_part_number,:export_ref_1,:export_date], {name: :export_idx}
    add_index :drawback_claim_audits, [:import_part_number,:import_entry_number,:import_ref_1], {name: :import_idx}
  end
end
