class CreateCanadianPgaLines < ActiveRecord::Migration
  def change
    create_table :canadian_pga_lines do |t|
      t.string :agency_code
      t.belongs_to :commercial_invoice_line
      t.string :batch_lot_number
      t.string :brand_name
      t.string :commodity_type
      t.string :country_of_origin
      t.string :exception_processes
      t.datetime :expiry_date
      t.string :fda_product_code
      t.string :file_name
      t.string :gtin
      t.string :importer_contact_name
      t.string :importer_contact_email
      t.string :importer_contact_phone
      t.string :intended_use_code
      t.string :lpco_number
      t.string :lpco_type
      t.datetime :manufacture_date
      t.string :model_designation
      t.string :model_label # 'model_name' is reserved
      t.string :model_number
      t.string :product_name
      t.string :program_code
      t.string :purpose
      t.string :state_of_origin
      t.string :unique_device_identifier

      t.timestamps
    end
  end
end
