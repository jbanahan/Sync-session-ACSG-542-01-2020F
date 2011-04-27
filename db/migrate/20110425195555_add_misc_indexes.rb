class AddMiscIndexes < ActiveRecord::Migration
  def self.up
    add_index :public_fields, :model_field_uid
    add_index :official_tariffs, [:country_id, :hts_code]
    add_index :official_quotas, [:country_id, :hts_code]
    add_index :messages, :user_id
    add_index :imported_files, :user_id
    add_index :file_import_results, [:imported_file_id,:finished_at]
    add_index :field_labels, :model_field_uid
    add_index :dashboard_widgets, :user_id
    add_index :companies, :carrier
    add_index :companies, :vendor
    add_index :companies, :master
    add_index :companies, :customer
    add_index :change_records, :file_import_result_id
    add_index :attachments, [:attachable_id,:attachable_type]
    add_index :addresses, :company_id
  end

  def self.down
    remove_index :public_fields, :model_field_uid
    remove_index :official_tariffs, [:country_id, :hts_code]
    remove_index :official_quotas, [:country_id, :hts_code]
    remove_index :messages, :user_id
    remove_index :imported_files, :user_id
    remove_index :file_import_results, [:imported_file_id,:finished_at]
    remove_index :field_labels, :model_field_uid
    remove_index :dashboard_widgets, :user_id
    remove_index :companies, :carrier
    remove_index :companies, :vendor
    remove_index :companies, :master
    remove_index :companies, :customer
    remove_index :change_records, :file_import_result_id
    remove_index :attachments, [:attachable_id,:attachable_type]
    remove_index :addresses, :company_id
  end
end
