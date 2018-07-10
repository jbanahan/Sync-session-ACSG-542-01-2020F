require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module ConfigMigrations; module LL; class LlPhase3
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def up
    cdefs
    generate_field_labels
    set_xml_tag_names
    nil
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [
      :ordln_po_create_article, :ordln_po_create_quantity, :ordln_po_create_hts, :ordln_po_create_price_per_unit, :ordln_po_create_total_price, :ordln_po_create_country_origin, 
      :ordln_po_create_bol, :ordln_po_create_container_number, :ordln_po_create_seal_number, :ordln_po_booked_article, :ordln_po_booked_quantity, :ordln_po_booked_hts, 
      :ordln_po_booked_price_per_unit, :ordln_po_booked_total_price, :ordln_po_booked_country_origin, :ordln_po_booked_bol, :ordln_po_booked_container_number, 
      :ordln_po_booked_seal_number, :ordln_po_shipped_article, :ordln_po_shipped_quantity, :ordln_po_shipped_hts, :ordln_po_shipped_price_per_unit, :ordln_po_shipped_total_price, 
      :ordln_po_shipped_country_origin, :ordln_po_shipped_bol, :ordln_po_shipped_container_number, :ordln_po_shipped_seal_number, :ord_shipment_reference, :ord_shipment_cargo_ready_date,
      :ord_shipment_booking_requested_date, :ord_shipment_booking_number, :ord_shipment_sent_to_carrier_date, :ord_shipment_booking_confirmed_date, :ord_shipment_booking_cutoff_date,
      :ord_asn_empty_out_gate_at_origin, :ord_asn_est_arrival_discharge, :ord_asn_est_departure, :ord_asn_delivered, :ord_asn_container_unloaded, :ord_asn_carrier_released, 
      :ord_asn_customs_released_carrier, :ord_asn_available_for_delivery, :ord_asn_full_ingate, :ord_asn_on_rail_destination, :ord_asn_rail_arrived_destination, :ord_asn_arrive_at_transship_port, 
      :ord_asn_depart_from_transship_port, :ord_asn_barge_depart, :ord_asn_barge_arrive, :ord_bill_of_lading, :ordln_shpln_line_number, :ordln_shpln_product, :ordln_shpln_quantity, 
      :ordln_shpln_cartons, :ordln_shpln_volume, :ordln_shpln_gross_weight, :ordln_shpln_container_number, :ordln_deleted_flag, :ord_bol_date, :ord_bill_of_lading]
    @cdefs
  end

  def set_xml_tag_names
    set_xml_tag_name(cdefs[:ord_shipment_booking_requested_date].model_field_uid, "ord-booking-requested-date")
    set_xml_tag_name(cdefs[:ord_shipment_booking_confirmed_date].model_field_uid, "ord-booking-confirmed-date")

    nil
  end

  def generate_field_labels
    fl = FieldLabel.where(model_field_uid:'shp_departure_last_foreign_port_date').first_or_create!
    fl.label = "Depart From Transship Port"
    fl.save!
  end

  private
    def set_xml_tag_name uid, tag_name
      fvr = FieldValidatorRule.where(model_field_uid: uid).first_or_create!
      if fvr.xml_tag_name.blank?
        fvr.update_attributes! xml_tag_name: tag_name
      end
    end

end; end; end 