class AddActiveOriginToCountries < ActiveRecord::Migration
  def change
    add_column :countries, :active_origin, :boolean
  end
end
