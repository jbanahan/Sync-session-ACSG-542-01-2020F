require 'open_chain/custom_handler/xml_helper'
require 'open_chain/integration_client_parser'

class JJillPOFix
  include OpenChain::CustomHandler::XmlHelper
  extend OpenChain::IntegrationClientParser

  def initialize 
    c = Company.find_by_system_code 'JJILL'

    # Delete all parts not on piece set
    c.importer_products.joins("LEFT OUTER JOIN order_lines ON order_lines.product_id = products.id").where("order_lines.id IS NULL").destroy_all

    cd = CustomDefinition.where(label:'Vendor Style',module_type:'Product').first
    c.importer_products.each do |p|
      cv = p.get_custom_value(cd)
      if !cv.blank? && !cv.value.blank?
        uid = "JJILL-#{cv.value}"
        other_p = Product.find_by_unique_identifier uid
        next if other_p
        p.unique_identifier = uid
        p.save!
      end
    end
  end
end