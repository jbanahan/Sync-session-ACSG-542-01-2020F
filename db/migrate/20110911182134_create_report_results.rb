class CreateReportResults < ActiveRecord::Migration
  def self.up
    create_table :report_results do |t|
      t.string :name
      t.datetime :run_at
      t.text :friendly_settings_json
      t.text :settings_json
      t.string :report_class
      t.string :report_data_file_name
      t.string :report_data_content_type
      t.integer :report_data_file_size
      t.datetime :report_data_updated_at
      t.string :status
      t.text :run_errors
      t.integer :run_by_id

      t.timestamps
    end

    add_index :report_results, :run_by_id
  end

  def self.down
    drop_table :report_results
  end
end
