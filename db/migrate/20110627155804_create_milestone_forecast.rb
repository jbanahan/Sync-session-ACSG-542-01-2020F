class CreateMilestoneForecast < ActiveRecord::Migration
  def self.up
    create_table :milestone_forecast_sets do |t|
      t.integer :piece_set_id
      t.string :state
      t.timestamps
    end
    create_table :milestone_forecasts do |t|
      t.integer :milestone_definition_id
      t.integer :milestone_forecast_set_id
      t.date :planned
      t.date :forecast
      t.string :state
      t.timestamps
    end

    add_index :milestone_forecast_sets, [:state], :name=>"mfs_state"
    add_index :milestone_forecast_sets, [:piece_set_id], :unique=>true, :name=>"one_per_piece_set"
    add_index :milestone_forecasts, [:state], :name=>"mf_state"
    add_index :milestone_forecasts, [:milestone_forecast_set_id,:milestone_definition_id], :unique=>true, :name=>"unique_forecasts"
  end

  def self.down
    drop_table :milestone_forecast_sets
    drop_table :milestone_forecasts
  end
end
