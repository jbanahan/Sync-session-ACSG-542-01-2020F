require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/alliance_product_support'

# This is mostly a copy paste from the generic alliance product generator
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberKewillProductGenerator < ProductGenerator
  include OpenChain::CustomHandler::AllianceProductSupport

  def self.run_schedulable opts = {}
    g = self.new
    f = nil
    begin
      f = g.sync_fixed_position
      g.ftp_file f
    ensure
      f.close! unless f.nil? || f.closed?
    end
    nil
  end

  def initialize custom_where = nil
    @custom_where = custom_where
  end

  def sync_code
    'Kewill'
  end
  
  def remote_file_name
    "#{Time.now.to_i}-LUMBER.DAT"
  end

  def preprocess_row row, opts = {}
    # Strip leading zeros
    row[0] = row[0].to_s.gsub(/^0+/, "")

    super row, opts
  end

  def fixed_position_map
    [
      {:len=>15}, #part number
      {:len=>40}, #name
      {:len=>10}  #hts 1
    ]
  end

  def query
    qry = <<-QRY
SELECT products.id,
products.unique_identifier,
products.name,
tariff_records.hts_1
FROM products
INNER JOIN classifications on classifications.country_id = (SELECT id FROM countries WHERE iso_code = "US") AND classifications.product_id = products.id
INNER JOIN tariff_records on length(tariff_records.hts_1)=10 AND tariff_records.classification_id = classifications.id
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
