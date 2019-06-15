class CreateTppHtsOverrides < ActiveRecord::Migration
  def change
    create_table :tpp_hts_overrides do |t|
      t.integer :trade_preference_program_id
      t.string :hts_code
      t.decimal :rate, precision: 8, scale: 4
      t.text :note
      t.date :start_date
      t.date :end_date

      t.timestamps null: false
    end
    add_index :tpp_hts_overrides, :trade_preference_program_id, name: 'tpp_id'
    add_index :tpp_hts_overrides, :hts_code
    add_index :tpp_hts_overrides, [:start_date, :end_date], name: 'active_dates'
  end
end
