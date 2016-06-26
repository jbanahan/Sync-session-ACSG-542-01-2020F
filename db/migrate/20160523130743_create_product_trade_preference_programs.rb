class CreateProductTradePreferencePrograms < ActiveRecord::Migration
  def change
    create_table :product_trade_preference_programs do |t|
      t.integer :product_id
      t.integer :trade_preference_program_id

      t.timestamps
    end
    add_index :product_trade_preference_programs, :product_id, {name: :ptpp_product_id}
    add_index :product_trade_preference_programs, :trade_preference_program_id, {name: :ptpp_trade_pref_id}
  end
end
