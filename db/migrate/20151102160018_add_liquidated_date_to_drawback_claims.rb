class AddLiquidatedDateToDrawbackClaims < ActiveRecord::Migration
  def up
    add_column :drawback_claims, :liquidated_date, :date
  end

  def down
    remove_column :drawback_claims, :liquidated_date
  end
end
