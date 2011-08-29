class CreateInstantClassificationResults < ActiveRecord::Migration
  def self.up
    create_table :instant_classification_results do |t|
      t.integer :run_by_id
      t.datetime :run_at
      t.datetime :finished_at

      t.timestamps
    end
    add_index :instant_classification_results, :run_by_id
  end

  def self.down
    drop_table :instant_classification_results
  end
end
