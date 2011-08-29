class CreateInstantClassifications < ActiveRecord::Migration
  def self.up
    create_table :instant_classifications do |t|
      t.string :name
      t.integer :rank

      t.timestamps
    end
  end

  def self.down
    drop_table :instant_classifications
  end
end
