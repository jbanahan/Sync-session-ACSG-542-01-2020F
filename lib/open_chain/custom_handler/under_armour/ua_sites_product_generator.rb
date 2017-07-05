require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/under_armour/ua_sites_subs_helper'

module OpenChain; module CustomHandler; module UnderArmour; class UaSitesProductGenerator < OpenChain::CustomHandler::ProductGenerator
  include OpenChain::CustomHandler::UnderArmour::UaSitesSubsHelper 
  
  def sync_code
    "ua_sites"
  end
  
  def query
    qry = <<-SQL
      SELECT p.id, p.unique_identifier, sites.text_value
      FROM products p
        INNER JOIN classifications cl ON p.id = cl.product_id
        INNER JOIN tariff_records t ON cl.id = t.classification_id
        INNER JOIN countries co ON co.id = cl.country_id
        INNER JOIN custom_values sites ON sites.customizable_id = p.id AND sites.customizable_type = "Product" AND sites.custom_definition_id = #{cdefs[:prod_site_codes].id}
    SQL

    if custom_where.blank?
      qry += " " + Product.need_sync_join_clause(sync_code, 'p')
      qry += " WHERE " + Product.need_sync_where_clause('p')
      qry += " AND LENGTH(t.hts_1) > 0"
      qry += %Q( AND sites.text_value <> "" AND (co.iso_code IN (#{site_countries.map{|s| '"'+s+'"' }.join(',')})))
    else
      qry += custom_where
    end

    qry += " GROUP BY p.id, p.unique_identifier, sites.text_value"
    qry += " ORDER BY p.unique_identifier ASC"
    qry
  end
  
  def preprocess_header_row row, opts={}
    [{0=>"Article", 1=>"Site Code", 2=>"Classification"}]
  end

  def preprocess_row row, opts={}
    out = []
    prod = products.find_by_unique_identifier row[0]
    row[1].split("\n ").each do |site|
      co = DataCrossReference.find_ua_country_by_site site
      if co
        hts = prod.classifications.find{ |cl| cl.country.iso_code == co }.tariff_records.first.try(:hts_1)
        out << {0=>prod.unique_identifier, 1=>site, 2=>hts.hts_format} if hts.present?
      end
    end
    out
  end
end
  
end; end; end;