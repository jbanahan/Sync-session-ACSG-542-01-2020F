class AddDutyRateDescriptionToCommercialInvoiceTariffs < ActiveRecord::Migration
  def change
    change_table :commercial_invoice_tariffs do |t|
      t.column :duty_rate_description, :string
    end
  end
end
