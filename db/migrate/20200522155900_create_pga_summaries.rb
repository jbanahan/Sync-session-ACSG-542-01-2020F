class CreatePgaSummaries < ActiveRecord::Migration
  def self.up
    create_table :pga_summaries do |t|
      t.integer :commercial_invoice_tariff_id, null: false
      t.integer :sequence_number
      t.string :agency_code
      t.string :program_code
      t.string :tariff_regulation_code
      t.string :commercial_description
      t.string :agency_processing_code
      t.string :disclaimer_type_code

      t.timestamps
    end

    add_index(:pga_summaries, [:commercial_invoice_tariff_id])
  end

  def self.down
    drop_table :pga_summaries
  end
end