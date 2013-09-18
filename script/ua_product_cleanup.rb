require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'
class UaProductCleanup
  include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport
  def self.color_cleanup
    cursor = 0
    total = ShipmentLine.count
    cd = self.prep_custom_definitions([:color])
    cache = {}
    ShipmentLine.scoped.each do |sl|
      puts "#{cursor} / #{total}" if (cursor % 500) == 0
      p_id = sl.product_id
      color = cache[p_id]
      if color.nil? && 
        p = sl.product
        if p.unique_identifier =~ '-/d{3}'
          color = p.split('-').last 
          cache[p_id] = color
        end
      end
      sl.update_custom_value! cd, color unless color.blank?
      cursor += 1
    end
  end

  def self.product_merge
    wc = "unique_identifier REGEXP '-[[:digit:]]{3}$'"
    cursor = 0
    p = Product.where(wc).first
    while !p.nil?
      style = p.unique_identifier.split('-').first
      p.update_attributes(unique_identifier:style)
      other_prods = Product.where("unique_identifier like ?","#{style}%")
      other_prods.each do |op|
        ShipmentLine.where(product_id:op.id).update_all(product_id:p.id)
        op.destroy
      end
      p = Product.where(wc).first
      puts Product.where(wc).count if (cursor % 500) == 0
      cursor += 1
    end
  end
end
