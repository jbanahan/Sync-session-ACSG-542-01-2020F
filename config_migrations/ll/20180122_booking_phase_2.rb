require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module ConfigMigrations; module LL; class BookingPhase2
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def up
    cdefs = generate_custom_definitions
    generate_field_labels
    generate_data_cross_references
    remove_cancelled_bookings_from_search_table_configs
    generate_state_toggle_buttons cdefs
    generate_field_validator_rules
    generate_isf_addresses
    set_countries_to_active_origin
    nil
  end

  def generate_custom_definitions
    @cdefs = self.class.prep_custom_definitions (
      [:shp_vgm_revised_date, :shp_vgm_revised_by, :shp_factory_pack_revised_date, :shp_factory_pack_revised_by, 
        :shp_vgm_electronic_signature, :shp_vgm_signature_date, :shp_isf_revised_by, :shp_isf_revised_date,
        :con_weighing_company, :con_weighed_date, :con_weighing_method, :con_cargo_weight, 
        :con_dunnage_weight, :con_tare_weight, :con_total_vgm_weight, :con_remarks]
    )
  end

  def generate_field_labels
    fl = FieldLabel.where(model_field_uid:'shp_packing_list_sent_date').first_or_create!
    fl.label = "Factory Pack Sent Date"
    fl.save!

    fl = FieldLabel.where(model_field_uid:'shp_packing_list_sent_by_fullname').first_or_create!
    fl.label = "Factory Pack Sent By (Name)"
    fl.save!

    fl = FieldLabel.where(model_field_uid:'shp_packing_list_sent_by_username').first_or_create!
    fl.label = "Factory Pack Sent By (Username)"
    fl.save!

    fl = FieldLabel.where(model_field_uid:'shp_packing_list_sent_by').first_or_create!
    fl.label = "Factory Pack Sent By"
    fl.save!

    fl = FieldLabel.where(model_field_uid: "shp_first_port_receipt_id").first_or_create!
    fl.label = "Delivery Location"
    fl.save!

    fl = FieldLabel.where(model_field_uid: "shp_first_port_receipt_name").first_or_create!
    fl.label = "Delivery Location Name"
    fl.save!

    fl = FieldLabel.where(model_field_uid: "shp_first_port_receipt_code").first_or_create!
    fl.label = "Delivery Location Code"
    fl.save!

    fl = FieldLabel.where(model_field_uid: "shp_booking_received_date").first_or_create!
    fl.label = "Booking Requested Date"
    fl.save!

    fl = FieldLabel.where(model_field_uid: "shp_importer_reference").first_or_create!
    fl.label = "Shipment Plan Number"
    fl.save!

    fl = FieldLabel.where(model_field_uid: "shp_booking_approved_date").first_or_create!
    fl.label = "Booking Sent to Carrier"
    fl.save!

    nil
  end

  def generate_data_cross_references
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_QUANTITY_UOM, key:'FTK', value:'SFQTY').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_QUANTITY_UOM, key:'FOT', value:'FTQTY').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_QUANTITY_UOM, key:'LBR', value:'LBS').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_QUANTITY_UOM, key:'EA', value:'EA').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_QUANTITY_UOM, key:'FT', value:'FTQTY').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_QUANTITY_UOM, key:'FT2', value:'SFQTY').first_or_create!

    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE, key:'20STD', value:'D20').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE, key:'40STD', value:'D40').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE, key:'40HQ', value:'HC40').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE, key:'45STD', value:'D45').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE, key:'53', value:'D53').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::LL_GTN_EQUIPMENT_TYPE, key:'LCL', value:'LCOS').first_or_create!
  end

  def remove_cancelled_bookings_from_search_table_configs
    non_cancelled_bookings = {"field" => "shp_canceled_date", "operator" => "null"}
    SearchTableConfig.where(page_uid: "chain-vp-shipment-panel").each do |config|
      h = config.config_hash
      h['hiddenCriteria'] = [] if h['hiddenCriteria'].nil?
      h['hiddenCriteria'] << non_cancelled_bookings
      config.config_hash = h
      config.save!
    end
  end

  def generate_state_toggle_buttons cdefs
    stb = StateToggleButton.where(identifier: "shp_send_isf", module_type: "Shipment").first_or_create! user_attribute: "shp_isf_sent_by", date_attribute: "shp_isf_sent_at"
    stb.update_attributes! display_index: "1", simple_button: true, activate_text: "Send ISF"

    stb = StateToggleButton.where(identifier: "shp_resend_isf", module_type: "Shipment").first_or_create! user_custom_definition_id: cdefs[:shp_isf_revised_by].id, date_custom_definition_id: cdefs[:shp_isf_revised_date].id
    stb.update_attributes! display_index: "2", simple_button: true, activate_text: "Resend ISF"

    stb = StateToggleButton.where(identifier: "shp_send_factory_pack", module_type: "Shipment").first_or_create! user_attribute: "shp_packing_list_sent_by", date_attribute: "shp_packing_list_sent_date"
    stb.update_attributes! display_index: "3", simple_button: true, activate_text: "Send Factory Pack" 

    stb = StateToggleButton.where(identifier: "shp_resend_factory_pack", module_type: "Shipment").first_or_create! user_custom_definition_id: cdefs[:shp_factory_pack_revised_by].id, date_custom_definition_id: cdefs[:shp_factory_pack_revised_date].id
    stb.update_attributes! display_index: "4", simple_button: true, activate_text: "Resend Factory Pack"

    # The following 2 fields should start their lives as disabled, as they're not to be shown on screen for the time being.  Don't update that except when creating
    stb = StateToggleButton.where(identifier: "shp_send_vgm", module_type: "Shipment").first_or_create! disabled: true, user_attribute: "shp_vgm_sent_by", date_attribute: "shp_vgm_sent_date"
    stb.update_attributes! display_index: "5", simple_button: true, activate_text: "Send VGM"

    stb = StateToggleButton.where(identifier: "shp_resend_vgm", module_type: "Shipment").first_or_create! disabled: true, user_custom_definition_id: cdefs[:shp_vgm_revised_by].id, date_custom_definition_id: cdefs[:shp_vgm_revised_date].id
    stb.update_attributes! display_index: "6", simple_button: true, activate_text: "Resend VGM"
    nil
  end

  def generate_field_validator_rules
    fvr = FieldValidatorRule.where(model_field_uid:"con_container_size", module_type:'Container').first_or_create!
    fvr.update_attributes!( one_of: "20STD\n40STD\n40HQ\n45STD\n53\nLCL" ) 
  end

  def generate_isf_addresses
    us = Country.where(iso_code:'US').first
    lumber = Company.where(system_code: "LUMBER").first

    # This system code is Lumber's EIN number (we're going to use this address for both the ISF Buyer and ISF Consignee)
    buyer = lumber.addresses.where(address_type: "ISF Buyer").first
    if buyer.nil?
      lumber.addresses.create! address_type: "ISF Buyer", system_code:'80-050596000', name:'LUMBER LIQUIDATORS SERVICES LLC', line_1:'3000 JOHN DEERE ROAD', city:'TOANO', state:'VA', postal_code:'23168', country_id: us.id
    end

    consignee = lumber.addresses.where(address_type: "ISF Consignee").first
    if consignee.nil?
      lumber.addresses.create! address_type: "ISF Consignee", system_code:'80-050596000', name:'LUMBER LIQUIDATORS SERVICES LLC', line_1:'3000 JOHN DEERE ROAD', city:'TOANO', state:'VA', postal_code:'23168', country_id: us.id
    end

    importer = lumber.addresses.where(address_type: "ISF Importer").first
    if importer.nil?
      lumber.addresses.create! address_type: "ISF Importer", system_code:'80-050596000', name:'LUMBER LIQUIDATORS SERVICES LLC', line_1:'3000 JOHN DEERE ROAD', city:'TOANO', state:'VA', postal_code:'23168', country_id: us.id
    end
    nil
  end

  def set_countries_to_active_origin
    Country.update_all active_origin: true
  end

end; end; end;