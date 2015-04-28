require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module Customer; class LumberLiquidatorsController < ApplicationController
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  def sap_vendor_setup_form
    @vendor = Company.find params[:vendor_id]
    custom_field_ids = [
      :cmp_primary_phone,
      :cmp_primary_fax,
      :cmp_business_address,
      :cmp_us_vendor,
      :cmp_vendor_type,
      :cmp_industry,
      :cmp_payment_terms,
      :cmp_payment_address,
      :cmp_requested_payment_method,
      :cmp_approved_payment_method,
      :cmp_dba_name,
      :cmp_purchasing_contact_name,
      :cmp_purchasing_contact_email,
      :cmp_a_r_contact_name,
      :cmp_a_r_contact_email,
      :cmp_pc_approved_date,
      :cmp_pc_approved_by,
      :cmp_merch_approved_by,
      :cmp_merch_approved_date,
      :cmp_legal_approved_date,
      :cmp_legal_approved_by,
      :cmp_pc_approved_by_executive,
      :cmp_pc_approved_date_executive,
    ]
    @@ll_cdefs ||= {}
    if @@ll_cdefs.empty?
      @@ll_cdefs = self.class.prep_custom_definitions custom_field_ids
    end
    @model_fields = [
      :cmp_name
    ]
    custom_field_ids.each do |cfid|
      @model_fields << @@ll_cdefs[cfid].model_field.uid
    end
    if MasterSetup.get.custom_feature?('Lumber SAP') && @vendor.can_view_as_vendor?(current_user)
      render layout: false
      return
    end
    raise ActionController::RoutingError.new('Not Found') 
  end
end; end