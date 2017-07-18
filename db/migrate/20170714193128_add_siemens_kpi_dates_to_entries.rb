class AddSiemensKpiDatesToEntries < ActiveRecord::Migration
  def change
    change_table :entries, bulk: true do |t|
      t.datetime :documentation_request_date
      t.datetime :po_request_date
      t.datetime :tariff_request_date
      t.datetime :ogd_request_date
      t.datetime :value_currency_request_date
      t.datetime :part_number_request_date
      t.datetime :importer_request_date
    end
  end
end
