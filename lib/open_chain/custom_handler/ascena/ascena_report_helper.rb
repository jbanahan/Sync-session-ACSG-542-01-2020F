module OpenChain; module CustomHandler; module Ascena; module AscenaReportHelper
  extend ActiveSupport::Concern

  SYSTEM_CODE = "ASCENA"

  def invoice_value_brand ord_alias, inv_line_alias, wholesale_unit_price_cdef_id, prod_reference_cdef_id, importer_system_code
    "#{inv_line_alias}.quantity * #{unit_price(ord_alias, inv_line_alias, wholesale_unit_price_cdef_id, prod_reference_cdef_id, importer_system_code)}"
  end

  def invoice_value_7501 inv_line_alias
    "#{inv_line_alias}.value"
  end

  def invoice_value_contract inv_line_alias
    "IF(#{inv_line_alias}.contract_amount > 0, #{inv_line_alias}.contract_amount, #{inv_line_alias}.value)"
  end

  def duty_savings_first_sale inv_line_alias
    "IF(#{inv_line_alias}.contract_amount IS NULL OR #{inv_line_alias}.contract_amount = 0, 0, (SELECT ROUND((l.contract_amount - l.value) * (t.duty_amount / t.entered_value), 2)
    FROM commercial_invoice_lines l
    INNER JOIN commercial_invoice_tariffs t ON l.id = t.commercial_invoice_line_id
    WHERE l.id = cil.id
    LIMIT 1 ))"
  end

  def unit_price_brand ord_alias, inv_line_alias, wholesale_unit_price_cdef_id, prod_reference_cdef_id, importer_system_code
    "#{unit_price(ord_alias, inv_line_alias, wholesale_unit_price_cdef_id, prod_reference_cdef_id, importer_system_code)}"
  end

  def unit_price_po ord_alias, inv_line_alias, prod_reference_cdef_id, importer_system_code
    <<-SQL
        (SELECT IFNULL((SELECT ordln.price_per_unit 
                        FROM order_lines ordln 
                          INNER JOIN products prod ON prod.id = ordln.product_id 
                        WHERE ordln.order_id = #{ord_alias}.id AND prod.unique_identifier = CONCAT("#{importer_system_code}-", #{inv_line_alias}.part_number)
                        LIMIT 1),
                       (SELECT ordln.price_per_unit 
                        FROM order_lines ordln 
                          INNER JOIN products prod ON prod.id = ordln.product_id
                          INNER JOIN custom_values prod_ref ON prod_ref.customizable_id = prod.id AND prod_ref.customizable_type = "Product" AND prod_ref.custom_definition_id = #{prod_reference_cdef_id}
                        WHERE ordln.order_id = #{ord_alias}.id AND prod_ref.string_value = #{inv_line_alias}.part_number
                        LIMIT 1)))
       SQL
  end

  def unit_price_7501 inv_line_alias
    "#{inv_line_alias}.value / #{inv_line_alias}.quantity"
  end

  private

  def unit_price ord_alias, inv_line_alias, wholesale_unit_price_cdef_id, prod_reference_cdef_id, importer_system_code
    <<-SQL
        (SELECT IFNULL((SELECT ordln_price.decimal_value
                        FROM order_lines ordln
                          INNER JOIN products prod ON prod.id = ordln.product_id
                          INNER JOIN custom_values ordln_price ON ordln_price.customizable_id = ordln.id AND ordln_price.customizable_type = "OrderLine" AND ordln_price.custom_definition_id = #{wholesale_unit_price_cdef_id}
                        WHERE ordln.order_id = #{ord_alias}.id AND prod.unique_identifier = CONCAT("#{importer_system_code}-", #{inv_line_alias}.part_number)
                        LIMIT 1),
                       (SELECT ordln_price.decimal_value
                        FROM order_lines ordln
                          INNER JOIN products prod ON prod.id = ordln.product_id
                          INNER JOIN custom_values prod_ref ON prod_ref.customizable_id = prod.id AND prod_ref.customizable_type = "Product" AND prod_ref.custom_definition_id = #{prod_reference_cdef_id}
                          INNER JOIN custom_values ordln_price ON ordln_price.customizable_id = ordln.id AND ordln_price.customizable_type = "OrderLine" AND ordln_price.custom_definition_id = #{wholesale_unit_price_cdef_id}
                        WHERE ordln.order_id = #{ord_alias}.id AND prod_ref.string_value = #{inv_line_alias}.part_number
                        LIMIT 1)))
      SQL
  end

  def fiscal_month_dates start_fiscal_year, start_fiscal_month, end_fiscal_year, end_fiscal_month
    ascena = Company.where(system_code: SYSTEM_CODE).first
    start_date = FiscalMonth.where(company_id: ascena.id, year: start_fiscal_year, month_number: start_fiscal_month)
                     .first.start_date.strftime("%Y-%m-%d")
    end_date   = FiscalMonth.where(company_id: ascena.id, year: end_fiscal_year, month_number: end_fiscal_month)
                     .first.start_date.strftime("%Y-%m-%d")
    [start_date, end_date]
  end

  module ClassMethods
    def linked_to_ascena? co
      ascena = Company.where(system_code: SYSTEM_CODE).first
      return false unless ascena
      co.linked_companies.to_a.include? ascena
    end
  end

end; end; end; end