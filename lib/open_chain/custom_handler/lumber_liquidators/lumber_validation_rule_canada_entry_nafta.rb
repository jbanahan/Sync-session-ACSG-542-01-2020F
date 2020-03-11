require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberValidationRuleCanadaEntryNafta < BusinessValidationRule
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include ValidatesCommercialInvoiceLine

  def run_child_validation(cil)
    msg = nil
    if cil.part_number.present?
      fta = get_product_fta_code cil.part_number
      if fta.to_s.upcase == 'NAFTA'
        msg = "Product '#{cil.part_number}' has been flagged for NAFTA review."
      end
    end
    msg
  end

  private
    # Lumber commercial invoices routinely feature the same part number on multiple lines.  Highest count
    # as of Feb 2020 is 28 dupes.  This method involves caching so we're not looking up the same product
    # over and over.
    def get_product_fta_code part_number
      @prod_cache ||= {}
      unless @prod_cache.key? part_number
        prod = Product.where("unique_identifier LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(part_number)}").first
        @cd_fta ||= self.class.prep_custom_definitions([:prod_fta])[:prod_fta]
        @prod_cache[part_number] = prod ? prod.get_custom_value(@cd_fta).try(:value) : nil
      end
      @prod_cache[part_number]
    end

end; end; end; end