# A report that inherits this module must implement class method .cust_info, which returns the members of the CUST_INFO constant
# that should be available to the report.

module OpenChain; module CustomHandler; module Ascena; module AscenaReportHelper
  extend ActiveSupport::Concern
  include OpenChain::Report::ReportHelper

  ANN_CUST_NUM = "ATAYLOR"
  ASCENA_CUST_NUM = "ASCE"
  MAURICES_CUST_NUM = "MAUR"

  ANN_SYS_CODE = "ATAYLOR"
  ASCENA_SYS_CODE = "ASCENA"
  MAURICES_SYS_CODE = "MAUR"

  CUST_INFO = [{cust_num: ASCENA_CUST_NUM, sys_code: ASCENA_SYS_CODE, name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"},
               {cust_num: ANN_CUST_NUM, sys_code: ANN_SYS_CODE, name: "ANN TAYLOR INC", short_name: "Ann"},
               {cust_num: MAURICES_CUST_NUM, sys_code: MAURICES_SYS_CODE, name: "MAURICES", short_name: "Maurices"}]

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def ascena
      Company.importers.with_customs_management_number(ASCENA_CUST_NUM).first
    end

    def ann
      Company.importers.with_customs_management_number(ANN_CUST_NUM).first
    end

    def maurices
      Company.importers.with_customs_management_number(MAURICES_CUST_NUM).first
    end

    def permission? user
      permissions(user).present?
    end

    def permissions user
      return [] unless MasterSetup.get.custom_feature?("Ascena Reports") && user.view_entries?
      trade_associate = Group.find_by system_code: "ASCE_TRADE_ASSOC"
      if user.company.master? || user.in_group?(trade_associate) || user.company == Company.with_customs_management_number("ASCENAMASTER").first
        available_customers
      else
        available_customers.select { |info| info[:cust_num] == user.company.kewill_customer_number }.compact
      end
    end

    def available_customers
      cust_info.select { |info| Company.with_customs_management_number(info[:cust_num]).first.present? }
    end

    def cust_short_names
      CUST_INFO.map { |ci| ci[:short_name] }.join("-")
    end

    def fiscal_month settings
      if settings['fiscal_month'].to_s =~ /(\d{4})-(\d{2})/
        year = $1
        month = $2
        FiscalMonth.where(company_id: ascena.id, year: year.to_i, month_number: month.to_i).first
      else
        nil
      end
    end

    def sys_codes_to_short_names sys_codes
      cust_info.select { |ci| Array.wrap(sys_codes).include? ci[:sys_code] }.map { |ci| ci[:short_name] }.join("-")
    end

    def cust_nums_to_short_names cust_nums
      cust_info.select { |ci| Array.wrap(cust_nums).include? ci[:cust_num] }.map { |ci| ci[:short_name] }.join("-")
    end

    def sys_code_to_cust_num sys_code
      cust_info.find { |ci| ci[:sys_code] == sys_code }.fetch :cust_num
    end

    def cust_num_to_sys_code cust_num
      cust_info.find { |ci| ci[:cust_num] == cust_num }.fetch :sys_code
    end
  end

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
    <<-SQL
      IF(#{inv_line_alias}.contract_amount IS NULL OR #{inv_line_alias}.contract_amount = 0,
         0,
         (SELECT IFNULL(ROUND((l.contract_amount - l.value) * (t.duty_amount / t.entered_value), 2), 0)
          FROM commercial_invoice_lines l
            INNER JOIN commercial_invoice_tariffs t ON l.id = t.commercial_invoice_line_id
          WHERE l.id = cil.id
          LIMIT 1 ))
    SQL
  end

  def unit_price_brand ord_alias, inv_line_alias, wholesale_unit_price_cdef_id, prod_reference_cdef_id, importer_system_code
    "#{unit_price(ord_alias, inv_line_alias, wholesale_unit_price_cdef_id, prod_reference_cdef_id, importer_system_code)}"
  end

  def unit_price_po ord_alias, inv_line_alias, prod_reference_cdef_id, importer_system_code
    sys_code = importer_system_code == MAURICES_SYS_CODE ? ASCENA_SYS_CODE : sanitize(importer_system_code)
    <<-SQL
        (SELECT IFNULL((SELECT ordln.price_per_unit
                        FROM order_lines ordln
                          INNER JOIN products prod ON prod.id = ordln.product_id
                        WHERE ordln.order_id = #{ord_alias}.id AND prod.unique_identifier = CONCAT("#{sys_code}-", #{inv_line_alias}.part_number)
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
    sys_code = importer_system_code == MAURICES_SYS_CODE ? ASCENA_SYS_CODE : sanitize(importer_system_code)
    <<-SQL
        (SELECT IFNULL((SELECT ordln_price.decimal_value
                        FROM order_lines ordln
                          INNER JOIN products prod ON prod.id = ordln.product_id
                          INNER JOIN custom_values ordln_price ON ordln_price.customizable_id = ordln.id AND ordln_price.customizable_type = "OrderLine" AND ordln_price.custom_definition_id = #{wholesale_unit_price_cdef_id}
                        WHERE ordln.order_id = #{ord_alias}.id AND prod.unique_identifier = CONCAT("#{sys_code}-", #{inv_line_alias}.part_number)
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
    ascena = self.class.ascena
    start_date = FiscalMonth.where(company_id: ascena.id, year: start_fiscal_year, month_number: start_fiscal_month)
                     .first.start_date.strftime("%Y-%m-%d")
    end_date   = FiscalMonth.where(company_id: ascena.id, year: end_fiscal_year, month_number: end_fiscal_month)
                     .first.start_date.strftime("%Y-%m-%d")
    [start_date, end_date]
  end

end; end; end; end
