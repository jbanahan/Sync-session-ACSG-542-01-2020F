class ChangeTariffAdjustmentPercentageScales < ActiveRecord::Migration
  def up
    execute "ALTER TABLE `trade_lanes` MODIFY COLUMN tariff_adjustment_percentage decimal(5,2)"
    execute "ALTER TABLE `trade_preference_programs` MODIFY COLUMN tariff_adjustment_percentage decimal(5,2)"
  end

  def down
    execute "ALTER TABLE `trade_lanes` MODIFY COLUMN tariff_adjustment_percentage decimal(4,2)"
    execute "ALTER TABLE `trade_preference_programs` MODIFY COLUMN tariff_adjustment_percentage decimal(4,2)"
  end
end
