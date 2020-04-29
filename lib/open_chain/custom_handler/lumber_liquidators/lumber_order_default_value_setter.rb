require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderDefaultValueSetter
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def self.set_defaults ord, entity_snapshot: true
    cdefs = prep_custom_definitions([:cmp_default_inco_term, :cmp_default_handover_port, :cmp_default_country_of_origin, :ord_country_of_origin])
    v = ord.vendor
    return if v.nil?
    run_snapshot = false
    save_order = false

    # ship_from
    current_ship_from = ord.ship_from_id
    address_search = v.addresses.where(shipping:true)
    if current_ship_from.blank? && address_search.count == 1
      ord.ship_from_id = address_search.pluck(:id).first
      save_order = true
    end

    # done with actual attributes so save them before
    # moving on to custom values
    if save_order
      ord.save!
      run_snapshot = true
    end

    # country of origin
    current_coo = ord.custom_value(cdefs[:ord_country_of_origin])
    if current_coo.blank?
      vendor_coo = v.custom_value(cdefs[:cmp_default_country_of_origin])
      if !vendor_coo.blank?
        ord.update_custom_value!(cdefs[:ord_country_of_origin], vendor_coo)
        run_snapshot = true
      end
    end

    ord.create_snapshot(User.integration, nil, "System Job: Order Default Value Setter") if entity_snapshot && run_snapshot

    run_snapshot
  end
end; end; end; end
