class CreateChargeCodes < ActiveRecord::Migration
  def self.up
    create_table :charge_codes do |t|
      t.string :code
      t.string :description
      t.boolean :apply_hst

      t.timestamps
    end
  end

  def self.down
    drop_table :charge_codes
  end
end
