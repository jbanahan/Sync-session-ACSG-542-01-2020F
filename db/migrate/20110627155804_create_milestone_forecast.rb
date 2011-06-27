class CreateMilestoneForecast < ActiveRecord::Migration
  def self.up
    create_table :milestone_forecasts do |t|
      t.integer :milestone_definition_id
      t.integer :piece_set_id
      t.date :planned
      t.date :forecast
      t.timestamps
    end

    add_index :milestone_forecasts, [:piece_set_id,:milestone_definition_id], :unique=>true, :name=>"unique_forecasts"
  end

  def self.down
    drop_table :milestone_forecasts
  end
end
