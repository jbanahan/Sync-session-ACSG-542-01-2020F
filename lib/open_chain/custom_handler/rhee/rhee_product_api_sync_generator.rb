require 'open_chain/custom_handler/vfitrack_product_api_sync_client'
require 'open_chain/custom_handler/rhee/rhee_custom_definition_support'

module OpenChain; module CustomHandler; module Rhee; class RheeProductApiSyncGenerator < OpenChain::CustomHandler::VfiTrackProductApiSyncClient
  include RheeCustomDefinitionSupport

  def initialize opts = {}
    @custom_where = opts[:where]
    @cdefs = self.class.prep_custom_definitions [:fda_product_code]
    super opts
  end

  def query
    qry = <<-QRY
SELECT products.id, products.unique_identifier, fda.string_value, iso.iso_code, r.line_number, r.hts_1 
FROM products products
INNER JOIN classifications c on products.id = c.product_id
INNER JOIN tariff_records r on r.classification_id = c.id 
INNER JOIN countries iso on iso.id = c.country_id and iso.iso_code = 'US'
LEFT OUTER JOIN custom_values fda on fda.customizable_id = products.id and fda.customizable_type = 'Product' and fda.custom_definition_id = #{@cdefs[:fda_product_code].id}
QRY
    if @custom_where.blank?
      qry += "\n" + Product.need_sync_join_clause(sync_code)
      qry += "\nWHERE " + Product.need_sync_where_clause + "\n AND r.hts_1 <> ''"
    else
      qry += "\nWHERE " + @custom_where
    end

    # Initialize the previous product var for the result parsing method
    @previous_product = nil
    qry
  end

  def query_row_map
    {
      product_id: 0,
      prod_uid: 1,
      fda_product_code: 2,
      class_cntry_iso: 3,
      hts_line_number: 4,
      hts_hts_1: 5
    }
  end

  def vfitrack_importer_syscode query_row
    "RHEE"
  end

end; end; end; end;