class AddLastAllianceProductPushAtToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :last_alliance_product_push_at, :datetime
  end
end
