require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'
require 'open_chain/custom_handler/product_generator'

module OpenChain; module CustomHandler; module UnderArmour; class UnderArmourSapProductGenerator < OpenChain::CustomHandler::ProductGenerator
  include UnderArmourCustomDefinitionSupport

  def self.run_schedulable opts={}
    g = self.new(opts)
    g.ftp_file g.sync_csv
  end

  def initialize opts = {}
    @cdefs = self.class.prep_custom_definitions [:expected_duty_rate]
    super
  end

  def sync_code
    "ua_sap"
  end

  def preprocess_header_row row, opts={}
    out = {}
    # Only keep the first four header columns
    4.times {|n| out[n] = row[n]}
    [out]
  end

  def query 
    qry = <<-QRY
SELECT products.id, co.iso_code as 'Country of Destination', products.unique_identifier as 'Material', t.hts_1 as 'HTS Code', cv.decimal_value as 'Duty Rate', d.value as 'Tariff Override Ride', ot.common_rate as 'Tariff Duty Rate'
FROM products products
INNER JOIN classifications c on products.id = c.product_id
INNER JOIN countries co on c.country_id = co.id
INNER JOIN tariff_records t on t.classification_id = c.id 
LEFT OUTER JOIN custom_values cv on c.id = cv.customizable_id and cv.customizable_type = 'Classification' and cv.custom_definition_id = #{@cdefs[:expected_duty_rate].id}
LEFT OUTER JOIN official_tariffs ot on ot.country_id = c.country_id and ot.hts_code = t.hts_1
LEFT OUTER JOIN data_cross_references d on concat(co.iso_code, '#{DataCrossReference.compound_key_token}', t.hts_1) = d.`key` AND d.cross_reference_type = '#{DataCrossReference::UA_DUTY_RATE}'
QRY
    if custom_where.blank?
      qry += " " + Product.need_sync_join_clause(sync_code)
      qry += " WHERE " + Product.need_sync_where_clause
      qry += " AND length(t.hts_1) > 0"
    else
      qry += custom_where
    end

    qry
  end

  def preprocess_row row, opts = {}
    out_row = {0=>row[0], 1=>row[1], 2=>row[2].to_s.hts_format}

    # We use the Duty rate values in this order...
    # 1) Expected Duty Rate
    # 2) Xref'ed Value
    # 3) Official Tariff value (if any)

    duty_rate = row[3]
    if duty_rate.blank? && !row[4].blank?
      duty_rate = BigDecimal.new(row[4])
    end

    if duty_rate.blank?
      duty_rate = parse_official_tariff_common_rate row[5]
    end

    out_row[3] = duty_rate
    [out_row]
  end

  def ftp_credentials
    {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRACK',:password=>'RL2VFftp',:folder=>"to_ecs/Ralph_Lauren/sap_#{@env==:qa ? 'qa' : 'prod'}"}
  end

  private

    def parse_official_tariff_common_rate common_rate
      rate = nil
      if !common_rate.blank?
        if common_rate =~ /^\d+(?:\.\d+)?\s*%?/
          rate = common_rate
        elsif common_rate.try(:upcase) == "FREE"
          rate = "0"
        end
      end

      rate ? BigDecimal.new(rate) : nil
    end

end; end; end; end;