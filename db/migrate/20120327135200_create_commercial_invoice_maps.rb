class CreateCommercialInvoiceMaps < ActiveRecord::Migration
  def self.up
    create_table :commercial_invoice_maps do |t|
      t.string :source_mfid
      t.string :destination_mfid

      t.timestamps
    end
  end

  def self.down
    drop_table :commercial_invoice_maps
  end
end
