require 'open_chain/custom_handler/vfitrack_product_api_sync_client'

module OpenChain; module CustomHandler; module Polo; class PoloProductApiSyncGenerator < OpenChain::CustomHandler::VfiTrackProductApiSyncClient

  def query
    qry = <<-QRY
SELECT products.id, products.unique_identifier, iso.iso_code, r.line_number, r.hts_1 
FROM products products
INNER JOIN classifications c on products.id = c.product_id
INNER JOIN tariff_records r on r.classification_id = c.id 
INNER JOIN countries iso on iso.id = c.country_id and iso.iso_code = 'CA'
QRY
    if @custom_where.blank?
      qry += "\n" + Product.need_sync_join_clause(sync_code)
      qry += "\nWHERE " + Product.need_sync_where_clause + "\n AND r.hts_1 <> ''"
    else
      qry += "\nWHERE " + @custom_where
    end

    qry
  end

  def query_row_map
    {
      product_id: 0,
      prod_uid: 1,
      class_cntry_iso: 2,
      hts_line_number: 3,
      hts_hts_1: 4
    }
  end

  def vfitrack_importer_syscode query_row
    "RLMASTER"
  end


end; end; end; end;