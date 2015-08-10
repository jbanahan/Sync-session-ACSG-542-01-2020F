class AddFdaDatesToCommercialInvoiceLines < ActiveRecord::Migration
  def up
    # This method adds all columns in a single statement, which means MySQL 
    # only runs a single table update.  On a huge table like commercial_invoice_lines
    # that's a net savings of somewhere on the order of 20-30 minutes of query time.
    change_table(:commercial_invoice_lines, bulk: true) do |t|
      t.column :fda_review_date, :datetime
      t.column :fda_hold_date, :datetime
      t.column :fda_release_date, :datetime
    end
  end

  def down
    change_table(:commercial_invoice_lines, bulk: true) do |t|
      t.remove :fda_review_date
      t.remove :fda_hold_date
      t.remove :fda_release_date
    end
  end
end
