class AddEtaToSecurityFiling < ActiveRecord::Migration
  def change
    add_column :security_filings, :estimated_vessel_arrival_date, :date
  end
end
