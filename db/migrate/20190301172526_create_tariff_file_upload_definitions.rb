class CreateTariffFileUploadDefinitions < ActiveRecord::Migration
  def self.up
    create_table :tariff_file_upload_definitions do |t|
      t.string :country_code
      t.string :filename_regex
      t.string :country_iso_alias

      t.timestamps
    end

    add_index :tariff_file_upload_definitions, [:country_code], name: "idx_country_code", unique: true

    create_table :tariff_file_upload_instances do |t|
      t.integer :tariff_file_upload_definition_id
      t.string :vfi_track_system_code
      t.string :country_iso_alias

      t.timestamps
    end

    add_index :tariff_file_upload_instances, [:tariff_file_upload_definition_id, :vfi_track_system_code], name: "idx_definition_id_vfi_track_system_code", unique: true

    create_table :tariff_file_upload_receipts do |t|
      t.integer :tariff_file_upload_instance_id
      t.string :filename

      t.timestamps
    end

  end

  def self.down
    drop_table :tariff_file_upload_receipts
    drop_table :tariff_file_upload_instances
    drop_table :tariff_file_upload_definitions
  end
end
