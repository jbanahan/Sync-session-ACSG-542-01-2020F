class CreateSecurityFilingLines < ActiveRecord::Migration
  def self.up
    create_table :security_filing_lines do |t|
      t.integer :security_filing_id
      t.integer :line_number
      t.integer :quantity
      t.string :hts_code
      t.string :part_number
      t.string :po_number
      t.string :commercial_invoice_number
      t.string :mid
      t.string :country_of_origin_code

      t.timestamps
    end
    add_index :security_filing_lines, :security_filing_id
    add_index :security_filing_lines, :part_number
    add_index :security_filing_lines, :po_number

    add_column :piece_sets, :security_filing_line_id, :integer
    add_index :piece_sets, :security_filing_line_id
  end

  def self.down
    remove_index :piece_sets, :security_filing_line_id
    remove_column :piece_sets, :security_filing_line_id
    drop_table :security_filing_lines
  end
end
