class CreateCustomReports < ActiveRecord::Migration
  def self.up
    create_table :custom_reports do |t|
      t.string :name
      t.integer :user_id
      t.string :type
      t.boolean :include_links

      t.timestamps
    end
    add_index :custom_reports, :type
    add_index :custom_reports, :user_id
    add_column :search_criterions, :custom_report_id, :integer
    add_column :search_columns, :custom_report_id, :integer
    add_column :search_schedules, :custom_report_id, :integer
    add_index :search_criterions, :custom_report_id
    add_index :search_columns, :custom_report_id
    add_index :search_schedules, :custom_report_id
  end

  def self.down
    remove_index :search_criterions, :custom_report_id
    remove_index :search_columns, :custom_report_id
    remove_index :search_schedules, :custom_report_id
    remove_column :search_criterions, :custom_report_id
    remove_column :search_columns, :custom_report_id
    remove_column :search_schedules, :custom_report_id
    drop_table :custom_reports
  end
end
