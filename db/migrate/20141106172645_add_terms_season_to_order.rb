class AddTermsSeasonToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :terms_of_sale, :string
    add_column :orders, :season, :string
    add_index :orders, :season
  end
end
