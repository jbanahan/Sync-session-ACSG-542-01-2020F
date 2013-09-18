require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'
class UaProductCleanup
  include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport
  def self.color_cleanup
    cd = self.prep_custom_definitions([:color]).first.id
    ActiveRecord::Base.connection.execute "INSERT INTO custom_values (customizable_id, customizable_type, string_value, created_at, updated_at, custom_definition_id)
(SELECT shipment_lines.id, 'ShipmentLine', right(products.unique_identifier,3), now(), now(), #{cd}
FROM shipment_lines INNER JOIN products on products.id = shipment_lines.product_id
WHERE products.unique_identifier REGEXP '-[[:digit:]]{3}$')"
  end

  def self.product_merge
    wc = "unique_identifier REGEXP '-[[:digit:]]{3}$'"
    cursor = 0
    p = Product.where(wc).first
    while !p.nil?
      style = p.unique_identifier.split('-').first
      Product.transaction do 
        p.update_attributes(unique_identifier:style)
        other_prods = Product.where("unique_identifier like ?","#{style}%")
        other_prods.each do |op|
          ShipmentLine.where(product_id:op.id).update_all(product_id:p.id)
          op.destroy
        end
      end
      p = Product.where(wc).first
      puts Product.where(wc).count if (cursor % 500) == 0
      cursor += 1
    end
  end
end
