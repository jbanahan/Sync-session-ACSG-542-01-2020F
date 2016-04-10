require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderDefaultValueSetter
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  def self.set_defaults ord
    cdefs = prep_custom_definitions([:cmp_default_inco_term,:cmp_default_handover_port,:cmp_default_country_of_origin,:ord_country_of_origin])
    v = ord.vendor
    return if v.nil?
    run_snapshot = false
    save_order = false

    # fob point
    current_fob = ord.fob_point
    if current_fob.blank?
      vendor_fob = v.get_custom_value(cdefs[:cmp_default_handover_port]).value
      if !vendor_fob.blank?
        ord.fob_point = vendor_fob
        save_order = true
      end
    end

    # inco terms
    current_inco_terms = ord.terms_of_sale
    if current_inco_terms.blank?
      vendor_inco_terms = v.get_custom_value(cdefs[:cmp_default_inco_term]).value
      if !vendor_inco_terms.blank?
        ord.terms_of_sale = vendor_inco_terms
        save_order = true
      end
    end

    # done with actual attributes so save them before
    # moving on to custom values
    if save_order
      ord.save!
      run_snapshot = true
    end

    # country of origin
    current_coo = ord.get_custom_value(cdefs[:ord_country_of_origin]).value
    if current_coo.blank?
      vendor_coo = v.get_custom_value(cdefs[:cmp_default_country_of_origin]).value
      if !vendor_coo.blank?
        ord.update_custom_value!(cdefs[:ord_country_of_origin],vendor_coo)
        run_snapshot = true
      end
    end

    if run_snapshot
      ord.create_snapshot(User.integration)
      return true
    else
      return false
    end
  end
end; end; end; end
