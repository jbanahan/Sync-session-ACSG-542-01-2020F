class AddLateFileDatesToSecurityFilings < ActiveRecord::Migration
  def change
    change_table :security_filings, bulk: true do |t|
      t.datetime :us_customs_first_file_date
      t.datetime :vessel_departure_date
    end
  end
end
