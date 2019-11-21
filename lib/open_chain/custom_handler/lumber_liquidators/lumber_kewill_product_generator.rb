require 'open_chain/custom_handler/vandegrift/kewill_product_generator'
require 'open_chain/custom_handler/alliance_product_support'

# This is mostly a copy paste from the generic alliance product generator, the main reason it exists
# is so that the custom definitions referenced by the main Kewill generator are not created in the Lumber instance.
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberKewillProductGenerator < OpenChain::CustomHandler::Vandegrift::KewillProductGenerator
  include OpenChain::CustomHandler::AllianceProductSupport

  def sync_code
    'Kewill'
  end

  def self.run_schedulable opts = {}
    opts = {"alliance_customer_number" => "LUMBER", "strip_leading_zeros" => true, "use_unique_identifier" => true}.merge opts
    super(opts)
  end

  def custom_defs
    @cdefs ||= self.class.prep_custom_definitions [:prod_country_of_origin, :prod_301_exclusion_tariff]
    @cdefs
  end

  def query
    # All the nulls are here to match the column outputs from the standard Kewill query
    qry = <<-QRY
SELECT products.id,
products.unique_identifier,
products.name,
tariff_records.hts_1, 
#{cd_s custom_defs[:prod_country_of_origin].id},
null,
null,
null,
null,
null,
null,
null,
null,
null,
null,
null,
null,
null,
null,
null,
null,
null,
#{cd_s custom_defs[:prod_301_exclusion_tariff]}
FROM products
INNER JOIN classifications on classifications.country_id = (SELECT id FROM countries WHERE iso_code = "US") AND classifications.product_id = products.id
INNER JOIN tariff_records on length(tariff_records.hts_1) >= 8 AND tariff_records.classification_id = classifications.id
QRY
    if @custom_where.blank?
      qry += "#{Product.need_sync_join_clause(sync_code)} 
WHERE 
#{Product.need_sync_where_clause()} "
    else 
      qry += "WHERE #{@custom_where} "
    end
  end

end; end; end; end
