require 'open_chain/custom_handler/lumber_liquidators/lumber_order_booking'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_pdf_generator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberCustomApiResponse

  def self.customize_order_response order, user, order_hash, params
    order_hash['us_country_id'] = Country.where(iso_code: "US").first.try(:id)
    order_hash['statement'] = OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator.carb_statement(order)
  end

  def self.customize_shipment_response shipment, user, shipment_hash, params
    custom = set_custom_attributes(shipment_hash)
    
    # If there's no delivery location, then don't bother marking it as invalid for the screen...user won't be able to 
    # book anyway, and we don't want to trip the error display until they actually select something
    if shipment.first_port_receipt_id.nil?
      custom["valid_delivery_location"] = true
    else
      custom["valid_delivery_location"] = OpenChain::CustomHandler::LumberLiquidators::LumberOrderBooking.valid_delivery_location?(shipment)
    end

    cdefs = custom_definitions([:con_weighed_date, :con_weighing_method, :con_total_vgm_weight, :con_cargo_weight, :con_dunnage_weight, :con_tare_weight])
    edit_shipment = shipment.can_edit?(user)
    custom["can_send_factory_pack"] = edit_shipment && can_send_factory_pack?(shipment, false)
    custom["can_resend_factory_pack"] = edit_shipment && can_send_factory_pack?(shipment, true)
    custom["can_send_vgm"] = edit_shipment && can_send_vgm?(shipment, false, cdefs)
    custom["can_resend_vgm"] = edit_shipment && can_send_vgm?(shipment, true, cdefs)
    custom["can_send_isf"] = edit_shipment && can_send_isf?(shipment, false)
    custom["can_resend_isf"] = edit_shipment && can_send_isf?(shipment, true)

    Array.wrap(shipment_hash["containers"]).each do |container_hash|
      add_container_custom_attributes(shipment, container_hash, cdefs)
    end
    nil
  end

  def self.set_custom_attributes hash
    c = hash["custom"]
    if c.nil?
      c = {}
      hash["custom"] = c
    end

    c
  end

  def self.add_container_custom_attributes shipment, container_hash, cdefs
    container = shipment.containers.find {|c| c.container_number == container_hash["con_container_number"]}
    return unless container

    attrs = set_custom_attributes container_hash
    attrs["has_all_vgm_data"] = container_has_vgm_fields?(container, cdefs)

    nil
  end

  def self.custom_definitions fields
    OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions fields
  end

  def self.can_send_factory_pack? shipment, resend
    if resend
      # If we're evaluating for the resend button, then we can't enable it until factory pack has already been sent once
      return false if shipment.packing_list_sent_date.nil?
    else
      # If we're evaluating the initial send, then return false if packing list has already been sent.
      return false if !shipment.packing_list_sent_date.nil?
    end

    return false if shipment.containers.length == 0
    return false if shipment.shipment_lines.length == 0

    # If any header field is missing a value for the factory pack, then it should not be allowed to be sent
    return false unless object_has_all_values?(shipment, ['shp_ven_id', 'shp_booking_number', 'shp_booking_vessel', 'shp_booking_voyage', 'shp_importer_reference'])

    shipment.containers.each do |c|
      return false unless object_has_all_values?(c, ['con_container_number', 'con_container_size', 'con_seal_number'])
    end

    shipment.shipment_lines.each do |l|
      return false unless object_has_all_values?(l, ['shpln_shipped_qty', 'shpln_carton_qty', 'shpln_cbms', 'shpln_gross_kgs'])
    end

    true
  end

  def self.can_send_vgm? shipment, resend, cdefs
    if resend
      # If we're evaluating for the resend button, then we can't enable it until vgm has already been sent once
      return false if shipment.vgm_sent_date.nil?
    else
      # If we're evaluating the initial send, then return false if vgm has already been sent.
      return false if !shipment.vgm_sent_date.nil?
    end

    return false unless object_has_all_values?(shipment, ['shp_ven_id', 'shp_booking_number'])

    return false if shipment.containers.length == 0
    return false if shipment.shipment_lines.length == 0

    shipment.containers.each do |c|
      return false unless container_has_vgm_fields?(c, cdefs)
    end

    true
  end

  def self.container_has_vgm_fields? container, cdefs
    return false unless object_has_all_values?(container, ['con_container_number', cdefs[:con_weighed_date], cdefs[:con_weighing_method], cdefs[:con_total_vgm_weight]])

    # If the weiging method used is 2, then there's additional fields required.
    if container.custom_value(cdefs[:con_weighing_method]).to_i == 2
      return false unless object_has_all_values?(container, [cdefs[:con_cargo_weight], cdefs[:con_dunnage_weight], cdefs[:con_tare_weight]])
    end

    true
  end

  def self.can_send_isf? shipment, resend
    if resend
      # If we're evaluating for the resend button, then we can't enable it until isf has already been sent once
      return false if shipment.isf_sent_at.nil?
    else
      # If we're evaluating the initial send, then return false if isf has already been sent.
      return false if !shipment.isf_sent_at.nil?
    end

    return false unless object_has_all_values?(shipment, ['shp_vessel', 'shp_voyage', 'shp_master_bill_of_lading', 'shp_est_departure_date', 'shp_booking_number',
      'shp_seller_address_id', 'shp_ship_to_address_id', 'shp_ship_from_id', 'shp_consolidator_address_id', 'shp_container_stuffing_address_id', 'shp_origin_cntry_id'])

    return false if shipment.shipment_lines.length == 0

    true
  end

  def self.object_has_all_values? obj, fields
    fields.all? {|f| field_has_value?(obj, f) }
  end
  private_class_method :object_has_all_values?


  def self.field_has_value? obj, uid
    mf = ModelField.find_by_uid uid
    return false if mf.blank?

    val = mf.process_export obj, nil

    # return false if value is nil or blank
    return false if val.nil? || (val.respond_to?(:blank?) && val.blank?)

    # If the object is numeric, then also validate that it's nonzero
    return false if mf.numeric? && val.zero?

    return true
  end
  private_class_method :field_has_value?

end; end; end; end