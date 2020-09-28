require 'open_chain/custom_handler/fenix_product_file_generator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberFenixProductFileGenerator < OpenChain::CustomHandler::FenixProductFileGenerator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def initialize fenix_customer_code, options = {}
    super
    @cdefs.merge!(self.class.prep_custom_definitions([:prod_fta]))
  end

  def spi_value classification, product
    fta = custom_value(product, :prod_fta)
    (fta&.upcase == "USMCA") ? super : ""
  end

  def country_of_origin product
    coo = super
    (coo&.upcase == "US") ? "UVA" : coo
  end

end; end; end; end
