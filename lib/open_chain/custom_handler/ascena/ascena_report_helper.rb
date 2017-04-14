module OpenChain; module CustomHandler; module Ascena; module AscenaReportHelper
  def invoice_value_brand ord_alias, inv_line_alias, wholesale_unit_price_cdef_id
    "#{inv_line_alias}.quantity * #{unit_price(ord_alias, inv_line_alias, wholesale_unit_price_cdef_id)}"
  end

  def invoice_value_7501 inv_line_alias
    "#{inv_line_alias}.value"
  end

  def invoice_value_contract inv_line_alias
    "IF(#{inv_line_alias}.contract_amount > 0, #{inv_line_alias}.contract_amount, #{inv_line_alias}.value)"
  end

  def rounded_entered_value tariff_alias
    "ROUND(#{tariff_alias}.entered_value)"
  end

  def unit_price_brand ord_alias, inv_line_alias, wholesale_unit_price_cdef_id
    "#{unit_price(ord_alias, inv_line_alias, wholesale_unit_price_cdef_id)}"
  end

  def unit_price_po ord_alias, inv_line_alias
    <<-SQL
         (SELECT ordln.price_per_unit 
          FROM order_lines ordln 
            INNER JOIN products prod ON prod.id = ordln.product_id 
          WHERE ordln.order_id = #{ord_alias}.id AND prod.unique_identifier = CONCAT("ASCENA-", #{inv_line_alias}.part_number)
          LIMIT 1)
       SQL
  end

  def unit_price_7501 inv_line_alias
    "#{inv_line_alias}.value / #{inv_line_alias}.quantity"
  end

  private

  def unit_price ord_alias, inv_line_alias, wholesale_unit_price_cdef_id
    <<-SQL
        (SELECT ordln_price.decimal_value
         FROM order_lines ordln
           INNER JOIN products prod ON prod.id = ordln.product_id
           INNER JOIN custom_values ordln_price ON ordln_price.customizable_id = ordln.id AND ordln_price.customizable_type = "OrderLine" AND ordln_price.custom_definition_id = #{wholesale_unit_price_cdef_id}
         WHERE #{ord_alias}.id = ordln.order_id AND prod.unique_identifier = CONCAT("ASCENA-", #{inv_line_alias}.part_number)
         LIMIT 1)
      SQL
  end

end; end; end; end