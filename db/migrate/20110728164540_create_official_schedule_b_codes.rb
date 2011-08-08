class CreateOfficialScheduleBCodes < ActiveRecord::Migration
  def self.up
    create_table :official_schedule_b_codes do |t|
      t.string :hts_code
      t.text :short_description
      t.text :long_description
      t.text :quantity_1
      t.text :quantity_2
      t.string :sitc_code
      t.string :end_use_classification
      t.string :usda_code
      t.string :naics_classification
      t.string :hitech_classification

      t.timestamps
    end
  end

  def self.down
    drop_table :official_schedule_b_codes
  end
end
