class AddLmdIdentifierToIntacctReceivables < ActiveRecord::Migration
  def up
    add_column :intacct_receivables, :lmd_identifier, :string
    add_index :intacct_receivables, :lmd_identifier
    # The following query pulls the appropriate identifier up from the lines to the header for the LMD fields
    qry = <<-QRY
UPDATE intacct_receivables r SET r.lmd_identifier = (
  SELECT concat_ws('~', l.broker_file, l.freight_file) FROM intacct_receivable_lines l WHERE l.broker_file <> '' AND l.freight_file <> '' AND l.location in ('11', '12') AND r.id = l.intacct_receivable_id LIMIT 1
)
WHERE r.company = 'LMD' AND r.customer_number = 'VANDE' and r.lmd_identifier IS NULL
QRY
    execute qry
  end

  def down
    remove_column :intacct_receivables, :lmd_identifier
  end
end
