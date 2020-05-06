module OpenChain; module CustomHandler; module UnderArmour; module UnderArmourBusinessLogic

  def article_number sku
    sku =~ /\A([^\-]+-[^\-]+)-[^\-]+\z/ ? $1 : sku
  end

  def prepack_article_number sku
    sku =~ /\A([^\-]+)-[^\-]+-[^\-]+\z/ ? $1 : sku
  end

  def total_units_per_inner_pack product
    exploded_qty = BigDecimal(0)
    product.variants.each do |var|
      exploded_qty += var.custom_value(bl_cdefs[:var_units_per_inner_pack]) || BigDecimal(0)
    end
    exploded_qty
  end

  def exploded_quantity ship_line
    ip_qty = total_units_per_inner_pack(ship_line.product)
    ip_qty * (ship_line.quantity || BigDecimal(0))
  end

  private

    def bl_cdefs
      @bl_cdefs ||= self.class.prep_custom_definitions([:var_units_per_inner_pack])
    end

end; end; end; end;