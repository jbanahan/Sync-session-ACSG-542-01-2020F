class AddEstimatedVesselSailingDateToSecurityFiling < ActiveRecord::Migration
  def change
    add_column :security_filings, :estimated_vessel_sailing_date, :date
  end
end
