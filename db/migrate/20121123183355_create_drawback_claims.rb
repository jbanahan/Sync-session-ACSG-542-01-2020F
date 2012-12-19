class CreateDrawbackClaims < ActiveRecord::Migration
  def self.up
    create_table :drawback_claims do |t|
      t.integer :importer_id
      t.string :name
      t.date :exports_start_date
      t.date :exports_end_date
      t.string :entry_number
      t.decimal :total_export_value, :precision => 11, :scale=>2
      t.integer :total_pieces_exported
      t.integer :total_pieces_claimed
      t.decimal :planned_claim_amount, :precision => 11, :scale=>2
      t.decimal :total_duty, :precision => 11, :scale=>2
      t.decimal :duty_claimed, :precision => 11, :scale=>2
      t.decimal :hmf_claimed, :precision => 11, :scale=>2
      t.decimal :mpf_claimed, :precision => 11, :scale=>2
      t.decimal :total_claim_amount, :precision => 11, :scale=>2
      t.date :abi_accepted_date
      t.date :sent_to_customs_date
      t.date :billed_date
      t.date :duty_check_received_date
      t.decimal :duty_check_amount, :precision => 11, :scale=>2

      t.timestamps
    end
    add_index :drawback_claims, :importer_id
    add_column :companies, :drawback, :boolean
    add_index :companies, :drawback
  end

  def self.down
    remove_index :companies, :drawback
    remove_column :companies, :drawback
    drop_table :drawback_claims
  end
end
