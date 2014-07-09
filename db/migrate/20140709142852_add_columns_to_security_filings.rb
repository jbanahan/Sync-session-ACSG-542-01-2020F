class AddColumnsToSecurityFilings < ActiveRecord::Migration
  def change
    add_column :security_filings, :cbp_updated_at, :datetime
    add_column :security_filings, :status_description, :string
    add_column :security_filings, :manufacturer_names, :text
  end
end
