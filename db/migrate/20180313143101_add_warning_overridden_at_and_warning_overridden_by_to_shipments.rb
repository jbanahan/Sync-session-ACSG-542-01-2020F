class AddWarningOverriddenAtAndWarningOverriddenByToShipments < ActiveRecord::Migration
  def up
    change_table :shipments, bulk: true do |t|
      t.column :warning_overridden_at, :datetime
      t.column :warning_overridden_by_id, :integer
    end
  end
end
