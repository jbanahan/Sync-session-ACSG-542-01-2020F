class CreateSearchRuns < ActiveRecord::Migration
  def self.up
    create_table :search_runs do |t|
      t.text :result_cache
      t.integer :position
      t.integer :search_setup_id

      t.timestamps
    end
  end

  def self.down
    drop_table :search_runs
  end
end
