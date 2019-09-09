class AddExceptionFieldsToEntry < ActiveRecord::Migration
  def change
    change_table :entries, bulk: true do |t|
      t.date :miscellaneous_entry_exception_date
      t.date :invoice_missing_date
      t.date :bol_discrepancy_date
      t.date :detained_at_port_of_discharge_date
      t.date :invoice_discrepancy_date
      t.date :docs_missing_date
      t.date :hts_missing_date
      t.date :hts_expired_date
      t.date :hts_misclassified_date
      t.date :hts_need_additional_info_date
      t.date :mid_discrepancy_date
      t.date :additional_duty_confirmation_date
      t.date :pga_docs_missing_date
      t.date :pga_docs_incomplete_date
    end
  end
end
