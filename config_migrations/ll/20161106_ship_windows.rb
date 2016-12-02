require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module ConfigMigrations; module LL; class ShipWindows
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  CDEF_FIELDS = [:ord_forecasted_handover_date,:ord_forecasted_ship_window_start]
  def prep_custom_definitions
    self.class.prep_custom_definitions CDEF_FIELDS
  end

  def up
    cdefs = prep_custom_definitions
    rename_forecasted_handover_date cdefs
    rename_ship_windows
    update_forecasted_ship_window_start cdefs
  end

  def down
    cdefs = prep_custom_definitions
    undo_rename_ship_windows
    undo_rename_forecasted_handover_date cdefs
  end

  def rename_ship_windows
    [[:ord_window_start,'Contractual Ship Window Start'],[:ord_window_end,'Contractual Ship Window End']].each do |pair|
      f = FieldLabel.where(model_field_uid:pair.first).first_or_create!
      f.update_attributes(label:pair.last)
    end
  end
  def undo_rename_ship_windows
    FieldLabel.where(model_field_uid:[:ord_window_end,:ord_window_start]).destroy_all
  end

  def rename_forecasted_handover_date cdefs
    cdefs[:ord_forecasted_handover_date].update_attributes(label:'Forecasted Ship Window End')
  end
  def undo_rename_forecasted_handover_date cdefs
    cdefs[:ord_forecasted_handover_date].update_attributes(label:'Forecasted Handover Date')
  end

  def update_forecasted_ship_window_start cdefs
    u = User.integration
    Order.where(closed_at:nil).find_in_batches(batch_size:100) do |orders|
      pp "Starting batch of 100 orders."
      orders.each do |o|
        fhd = o.custom_value(cdefs[:ord_forecasted_handover_date])
        next unless fhd
        pp "Writing value for order #{o.order_number}"
        o.update_custom_value!(cdefs[:ord_forecasted_ship_window_start],fhd-7.days)
        o.create_snapshot(u,nil,"System Update: Initial Forecasted Ship Window Start load.")
      end
    end
  end
end; end; end
