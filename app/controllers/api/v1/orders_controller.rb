require 'open_chain/business_rule_validation_results_support'
require 'open_chain/api/v1/order_api_json_generator'

module Api; module V1; class OrdersController < Api::V1::ApiCoreModuleControllerBase
  include OpenChain::BusinessRuleValidationResultsSupport

  def core_module
    CoreModule::ORDER
  end

  def by_order_number
    obj = Order.where(order_number: params[:order_number]).first
    render_obj obj
  end

  def accept
    o = Order.find params[:id]
    unless o.can_view?(current_user) && o.can_accept?(current_user)
      raise StatusableError.new("Access denied.", :unauthorized)
    end
    raise StatusableError.new("Order #{o.order_number} cannot be accepted at this time.") unless o.can_be_accepted?
    o.async_accept! current_user
    redirect_to "/api/v1/orders/#{o.id}"
  end

  def unaccept
    o = Order.find params[:id]
    raise StatusableError.new("Access denied.", :unauthorized) unless o.can_view?(current_user) && o.can_accept?(current_user)
    o.async_unaccept! current_user
    redirect_to "/api/v1/orders/#{o.id}"
  end

  def save_object h
    ord = h['id'].blank? ? Order.new : Order.includes([
      {order_lines: [:piece_sets,{custom_values:[:custom_definition]},:product]},
      {custom_values:[:custom_definition]}
    ]).find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if ord.nil?
    ord.assign_model_field_attributes(h,skip_not_editable:true)
    raise StatusableError.new("You do not have permission to save this Order.",:forbidden) unless ord.can_edit?(current_user)
    ord.save! if ord.errors.full_messages.blank?
    ord
  end

  def json_generator
    OpenChain::Api::V1::OrderApiJsonGenerator.new
  end

  def validate
    ord = Order.find params[:id]
    run_validations(ord)
  end

end; end; end
