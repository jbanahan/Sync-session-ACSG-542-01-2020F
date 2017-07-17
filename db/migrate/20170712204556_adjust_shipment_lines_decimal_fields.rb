class AdjustShipmentLinesDecimalFields < ActiveRecord::Migration
  def up
    change_table :shipment_lines, bulk: true do |t|
      t.change :gross_kgs, :decimal, precision: 13, scale: 4
      t.change :cbms, :decimal, precision: 13, scale: 4
    end
  end
end
