require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberValidationRuleOrderVendorVariant
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def run_validation order
    @cd_pva_pc_approved_date = self.class.prep_custom_definitions([:pva_pc_approved_date])[:pva_pc_approved_date]
    failures = []
    vend = order.vendor
    if vend
      order.order_lines.collect {|ol| ol.product}.uniq.each do |p|
        failure_message = validate_product(vend,p)
        failures << failure_message unless failure_message.blank?
      end
    end
    return failures.empty? ? nil : failures.join("\n")
  end

  def validate_product vendor, product
    plant_ids = vendor.plants.pluck(:id)
    variant_ids = product.variants.pluck(:id)
    pv_assignments = PlantVariantAssignment.where('plant_id IN (?)',plant_ids).where('variant_id IN (?)',variant_ids).to_a
    return "Product \"#{product.unique_identifier}\" does not have a variant assigned to vendor \"#{vendor.name}\"." if pv_assignments.blank?
    pv_assignments.each do |pva|
      return nil if !pva.get_custom_value(@cd_pva_pc_approved_date).value.blank?
    end
    return "Product \"#{product.unique_identifier}\" does not have an approved variant for \"#{vendor.name}\"."
  end
  private :validate_product
end; end; end; end