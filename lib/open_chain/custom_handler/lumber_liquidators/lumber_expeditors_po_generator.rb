require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberExpeditorsPoGenerator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  UOM_TABLE = { "EA" => "EA", "FOT" => "FT", "FT2" => "SFT", "FTK" => "SFT" }

  HEADER = ["orderNumber", "orderIssueDate", "vendorNumber", "consigneeName", "buyerName", "orderDepartment", "orderDivision",
            "orderWarehouse", "orderEarlyShipDate", "orderLateShipDate", "orderRequiredDeliveryDate", "orderMode", "orderIncoterms",
            "orderCountryOfOrigin", "orderPortOfDestination", "orderReference1", "orderReference2", "orderReference3", "orderReference4",
            "itemSkuNumber", "itemLineNumber", "itemQuantity", "itemQuantityUom", "itemOuterPackQuantity", "itemPackQuantityUom", "itemPrice",
            "itemCurrencyCode", "itemHtsNumber", "itemDescription", "itemColor", "itemSize", "itemDepartment", "itemDivision", "itemWarehouse",
            "itemEarlyShipDate", "itemLateShipDate", "itemRequiredDeliveryDate", "itemReference1", "itemReference2", "itemReference3"]

  VALIDATE = {"orderNumber" => {required: true, max_len: 36},
              "orderIssueDate" => {required: false, max_len: 8},
              "vendorNumber" => {required: true, max_len: 40},
              "orderEarlyShipDate" => {required: false, max_len: 8},
              "orderLateShipDate" => {required: false, max_len: 8},
              "orderIncoTerms" => {required: false, max_len: 3},
              "orderCountryOfOrigin" => {required: false, max_len: 2},
              "orderReference1" => {required: false, max_len: 40},
              "itemSkuNumber" => {required: true, max_len: 36},
              "itemLineNumber" => {required: false, max_len: 10},
              "itemQuantity" => {required: true, max_len: 8},
              "itemQuantityUom" => {required: false, max_len: 3},
              "itemPrice" => {required: false, max_len: 12},
              "itemCurrencyCode" => {required: false, max_len: 3},
              "itemHtsNumber" => {required: false, max_len: 12},
              "itemDescription" => {required: false, max_len: 80},
              "itemDepartment" => {required: false, max_len: 16},
              "itemWarehouse" => {required: false, max_len: 16},
              "itemReference1" => {required: false, max_len: 40},
              "itemReference2" => {required: false, max_len: 20}}

  def generate_tsv ord_list
    cdefs = self.class.prep_custom_definitions [:ord_country_of_origin, :ord_assigned_agent, :prod_merch_cat, :prod_merch_cat_desc, :ordln_old_art_number]
    CSV.generate(col_sep:"\t") do |tsv|
      row_num = 1
      tsv << HEADER
      ord_list.each do |ord|
        ord_fields = get_order_fields(cdefs, ord, row_num + 1)
        ord.order_lines.each do |ordln|
          row = []
          row_num += 1
          row << ord_fields[:order_number]
          row << ord_fields[:order_issue_date]
          row << ord_fields[:vendor_number]
          row << "Lumber Liquidators"
          row << nil << nil << nil << nil
          row << ord_fields[:order_early_ship_date]
          row << ord_fields[:order_late_ship_date]
          row << nil
          row << "O"
          row << ord_fields[:order_inco_terms]
          row << ord_fields[:order_country_of_origin]
          row << nil
          row << ord_fields[:order_reference_1]
          row << nil << nil << nil
          row << filter("itemSkuNumber", ordln.product.unique_identifier, row_num)
          row << filter("itemLineNumber", ordln.line_number, row_num)
          row << filter("itemQuantity", ordln.quantity, row_num)
          row << table_filter(UOM_TABLE, "itemQuantityUom", ordln.unit_of_measure, row_num)
          row << nil
          row << "CTN"
          row << filter("itemPrice", ordln.price_per_unit, row_num)
          row << ord_fields[:item_currency_code]
          row << filter("itemHtsNumber", get_hts(ordln), row_num)
          row << filter("itemDescription", ordln.product.name, row_num)
          row << nil << nil
          row << filter("itemDepartment", ordln.product.get_custom_value(cdefs[:prod_merch_cat]).value, row_num)
          row << nil
          row << filter("itemWarehouse", ordln.ship_to.system_code, row_num)
          row << nil << nil << nil
          row << filter("itemReference1", ordln.product.get_custom_value(cdefs[:prod_merch_cat_desc]).value, row_num)
          row << filter("itemReference2", ordln.get_custom_value(cdefs[:ordln_old_art_number]).value, row_num)
          row << nil
          tsv << row
        end
      end
    end
  end

  private

  def get_order_fields cdefs, ord, row_num
    { order_number: filter("orderNumber", ord.order_number, row_num),
      order_issue_date: filter("orderIssueDate", ord.order_date.try(:strftime, '%Y%m%d'), row_num),
      vendor_number: filter("vendorNumber", ord.vendor.system_code, row_num),
      order_early_ship_date: filter("orderEarlyShipDate", ord.ship_window_start.try(:strftime, '%Y%m%d'), row_num),
      order_late_ship_date: filter("orderLateShipDate", ord.ship_window_end.try(:strftime, '%Y%m%d'), row_num),
      order_inco_terms: filter("orderIncoTerms", ord.terms_of_sale, row_num),
      order_country_of_origin: filter("orderCountryOfOrigin", ord.get_custom_value(cdefs[:ord_country_of_origin]).value, row_num),
      order_reference_1: filter("orderReference1", ord.get_custom_value(cdefs[:ord_assigned_agent]).value, row_num),
      item_currency_code: filter("itemCurrencyCode", ord.currency, row_num) }
  end

  def filter field_name, field, row_num
    if field.presence.nil? && VALIDATE[field_name][:required]
      raise "Missing mandatory field on line #{row_num}: #{field_name}"
    elsif field.to_s.length > VALIDATE[field_name][:max_len]
      raise "Field exceeding length limit on line #{row_num}: #{field_name}"
    end
    field.presence
  end

  def table_filter table, field_name, field, row_num
    if table[field].nil?
      raise "Field value not found in cross-reference table on line #{row_num}: #{field_name}"
    end
    table[field]
  end

  def get_hts ordln
    ordln.product
         .classifications
         .find_by_country_id(ordln.ship_to.try(:country_id))
         .try(:tariff_records).try(:first).try(:hts_1)
  end

end; end; end; end
