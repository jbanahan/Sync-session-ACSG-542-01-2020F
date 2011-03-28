class CreateDashboardWidgets < ActiveRecord::Migration
  def self.up
    create_table :dashboard_widgets do |t|
      t.integer :user_id
      t.integer :search_setup_id
      t.integer :rank
      t.timestamps
    end
  end

  def self.down
    drop_table :dashboard_widgets
  end
end
