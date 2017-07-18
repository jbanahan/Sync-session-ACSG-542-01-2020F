require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/under_armour/ua_sites_subs_helper'

module OpenChain; module CustomHandler; module UnderArmour; class UaSubsProductGenerator < OpenChain::CustomHandler::ProductGenerator
  include OpenChain::CustomHandler::UnderArmour::UaSitesSubsHelper 

  def sync_code
    "ua_subs"
  end 

  def query
    qry = <<-SQL
      SELECT DISTINCT p.id, '' as 'Country', p.unique_identifier as 'Article', '' as 'Classification'
      FROM products p
        INNER JOIN classifications cl ON p.id = cl.product_id
        INNER JOIN tariff_records t ON cl.id = t.classification_id
        INNER JOIN countries co ON co.id = cl.country_id
        LEFT OUTER JOIN custom_values sites ON sites.customizable_id = p.id AND sites.customizable_type = "Product" AND sites.custom_definition_id = #{cdefs[:prod_site_codes].id}
    SQL
 
    if custom_where.blank?
      qry += " " + Product.need_sync_join_clause(sync_code, 'p')
      qry += " WHERE " + Product.need_sync_where_clause('p')
      qry += " AND LENGTH(t.hts_1) > 0"
      qry += %Q( AND (co.iso_code NOT IN (#{site_countries.map{|s| '"'+s+'"' }.join(',')})))
    else
      qry += custom_where
    end
 
    qry += " GROUP BY p.id, p.unique_identifier"
    qry += " ORDER BY p.unique_identifier ASC"
    qry
  end

  def preprocess_row row, opts={}
    out = []
    prod = products.find_by_unique_identifier row[1]
    prod.classifications.reject{ |cl| site_countries.include? cl.country.iso_code }.each do |cl|
      co = cl.country
      hts = cl.tariff_records.first.try(:hts_1)
      out << {0=>co.iso_code, 1=>prod.unique_identifier, 2=>hts.hts_format} if hts.present?
    end
    out
  end
end

end; end; end;