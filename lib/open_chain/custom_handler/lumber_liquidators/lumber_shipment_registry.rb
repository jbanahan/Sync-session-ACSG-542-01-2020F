require 'open_chain/registries/default_shipment_registry'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberShipmentRegistry < OpenChain::Registries::DefaultShipmentRegistry

  def self.can_uncancel? shipment, user
    return false
  end

  def self.can_cancel? shipment, user
    return shipment.canceled_date.nil? && shipment.can_edit?(user) && (can_cancel_as_agent?(shipment, user) || shipment.can_cancel_by_role?(user))
  end

  def self.cancel_shipment_hook shipment, user
    # Lumber shipments need to have all booking lines destroyed upon cancellation.
    shipment.booking_lines.destroy_all
  end

  def self.can_cancel_as_agent? shipment, user
    qry = agent_qry(shipment.id)
    return false unless qry && user.company.agent?
    agent_results = ActiveRecord::Base.connection.execute qry
    agent_results.each { |ar| return false unless !ar[0].blank? && ar[0].upcase == user.company.system_code.to_s.upcase  }
    true
  end
  private_class_method :can_cancel_as_agent?

  def self.agent_qry shipment_id
    cdef = CustomDefinition.find_by cdef_uid: "ord_assigned_agent"
    return unless cdef

    <<-SQL
      SELECT agents.string_value
      FROM shipments s
        INNER JOIN shipment_lines sl ON s.id = sl.shipment_id
        INNER JOIN piece_sets ps ON sl.id = ps.shipment_line_id
        INNER JOIN order_lines ol ON ol.id = ps.order_line_id
        INNER JOIN orders o ON o.id = ol.order_id
        LEFT OUTER JOIN custom_values agents ON o.id = agents.customizable_id AND agents.customizable_type = "ORDER" AND agents.custom_definition_id = #{cdef.id}
      WHERE s.id = #{shipment_id}
      UNION DISTINCT
      SELECT agents.string_value
      FROM shipments s
        INNER JOIN booking_lines bl ON s.id = bl.shipment_id
        INNER JOIN order_lines ol ON ol.id = bl.order_line_id
        INNER JOIN orders o ON o.id = ol.order_id
        LEFT OUTER JOIN custom_values agents ON o.id = agents.customizable_id AND agents.customizable_type = "ORDER" AND agents.custom_definition_id = #{cdef.id}
      WHERE s.id = #{shipment_id}
    SQL
  end
  private_class_method :agent_qry

end; end; end; end;
