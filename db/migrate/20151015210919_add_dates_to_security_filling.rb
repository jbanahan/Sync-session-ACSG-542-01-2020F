class AddDatesToSecurityFilling < ActiveRecord::Migration
  def change
    add_column :security_filings, :ams_match_date, :datetime
    add_column :security_filings, :delete_accepted_date, :datetime
  end
end
