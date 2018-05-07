require 'open_chain/business_rule_validation_results_support'
require 'open_chain/api/v1/product_api_json_generator'

module Api; module V1; class ProductsController < Api::V1::ApiCoreModuleControllerBase
  include OpenChain::BusinessRuleValidationResultsSupport

  def core_module
    CoreModule::PRODUCT
  end

  def by_uid
    # path_uid is a route parameter that's defined solely for temporary backwards compatibility until all api sync clients
    # running in other instances can be fixed to send the uid as a query param instead.
    unique_identifier = params[:uid].presence || params[:path_uid]
    product = base_relation.where(unique_identifier: unique_identifier).first
    render_obj product
  end

  def render_obj obj
    if obj
      obj.freeze_all_custom_values_including_children
    end
    super obj
  end

  def model_fields
    render_model_field_list CoreModule::PRODUCT
  end

  def save_object obj_hash
    generic_save_object obj_hash
  end

  def find_object_by_id id
    base_relation.where(id: id).first
  end

  def base_relation
    # Don't pre-load custom values, they'll be loaded later by the custom value freeze (which is actually more efficient)
    Product.includes([{classifications: [:tariff_records]}, :variants])
  end

  def validate
    prod = Product.find params[:id]
    run_validations prod
  end

  def json_generator
    OpenChain::Api::V1::ProductApiJsonGenerator.new
  end

end; end; end
