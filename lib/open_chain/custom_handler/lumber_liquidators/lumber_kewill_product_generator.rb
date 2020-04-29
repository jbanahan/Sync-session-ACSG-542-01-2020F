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
    opts = {"alliance_customer_number" => "LUMBER", "strip_leading_zeros" => true, "use_unique_identifier" => true, "suppress_fda_data" => true}.merge opts
    super(opts)
  end

  def custom_defs
    @cdefs ||= self.class.prep_custom_definitions [:prod_country_of_origin, :prod_301_exclusion_tariff, :prod_add_case, :prod_cvd_case, :class_special_program_indicator]
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
#{cd_s custom_defs[:prod_301_exclusion_tariff]},
#{cd_s custom_defs[:prod_cvd_case]},
#{cd_s custom_defs[:prod_add_case]},
#{cd_s custom_defs[:class_special_program_indicator]}
FROM products
INNER JOIN classifications on classifications.country_id = (SELECT id FROM countries WHERE iso_code = "US") AND classifications.product_id = products.id
INNER JOIN tariff_records on length(tariff_records.hts_1) >= 8 AND tariff_records.classification_id = classifications.id
QRY
    if self.custom_where.blank?
      qry += "#{Product.need_sync_join_clause(sync_code)}
WHERE
#{Product.need_sync_where_clause()} "
    else
      qry += "WHERE #{self.custom_where} "
    end
  end

  def map_product_header_data d, row
    base_product_header_mapping(d, row)

    d.description = row[1].to_s.upcase
    d.country_of_origin = row[3]
    d.exclusion_301_tariff = row[4]

    nil
  end

  def map_tariff_number_data product, row
    t = tariffs(product, row)
    spi = row[7]

    if spi.present?
      set_value_in_tariff_data(t, "spi", spi)
    end

    t
  end

  def has_fda_data? row
    false
  end

  def map_penalty_data product, row
    penalties = []

    if row[5].present?
      d = PenaltyData.new
      d.penalty_type = "CVD"
      d.case_number = row[5]
      penalties << d
    end

    if row[6].present?
      d = PenaltyData.new
      d.penalty_type = "ADA"
      d.case_number = row[6]
      penalties << d
    end

    penalties
  end

end; end; end; end
