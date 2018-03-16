require 'spec_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

class Report
  include OpenChain::CustomHandler::Ascena::AscenaReportHelper

  def run_query cdefs
    ActiveRecord::Base.connection.exec_query query(cdefs)
  end
  
  def query cdefs
    unit_price_cdef_id = cdefs[:ord_line_wholesale_unit_price].id
    ref_cdef_id = cdefs[:prod_reference_number].id
    <<-SQL
      SELECT #{invoice_value_brand('o', 'cil', unit_price_cdef_id, ref_cdef_id, SYSTEM_CODE)} AS 'Invoice Value - Brand', 
             #{invoice_value_7501('cil')} AS 'Invoice Value - 7501', 
             #{invoice_value_contract('cil')} AS 'Invoice Value - Contract', 
             #{unit_price_brand('o', 'cil', unit_price_cdef_id, ref_cdef_id, SYSTEM_CODE)} AS 'Unit Price - Brand', 
             #{unit_price_po('o', 'cil', ref_cdef_id, SYSTEM_CODE)} AS 'Unit Price - PO', 
             #{unit_price_7501('cil')} AS 'Unit Price - 7501'
      FROM commercial_invoices ci
        INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
        INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
        LEFT OUTER JOIN orders o ON o.order_number = CONCAT("ASCENA-", cil.po_number)
    SQL
  end
end

describe OpenChain::CustomHandler::Ascena::AscenaReportHelper do  
  let(:report) { Report.new }
  
  before do
    @cdefs = self.class.prep_custom_definitions [:ord_line_wholesale_unit_price, :prod_reference_number]
    @ci = Factory(:commercial_invoice)
    @cil = Factory(:commercial_invoice_line, commercial_invoice: @ci, quantity: 3, part_number: "part num", po_number:'po num', contract_amount: 4, value: 2)
    @cit = Factory(:commercial_invoice_tariff, commercial_invoice_line: @cil, entered_value: 5.5)
    @p = Factory(:product, unique_identifier: "ASCENA-part num")
    @p.update_custom_value!(@cdefs[:prod_reference_number], "part num")
    @o = Factory(:order, order_number: "ASCENA-po num")
    @ol = Factory(:order_line, order: @o, product: @p, price_per_unit: 6)
    @ol.update_custom_value!(@cdefs[:ord_line_wholesale_unit_price], 7)
  end

  it "returns expected results when products are linked by unique_id" do
    result = report.run_query @cdefs
    expect(result.columns).to eq ["Invoice Value - Brand", "Invoice Value - 7501", "Invoice Value - Contract",
                                  "Unit Price - Brand", "Unit Price - PO", "Unit Price - 7501"]
    expect(result.count).to eq 1
    expect(result.first).to eq(
      {"Invoice Value - Brand" => 21, "Invoice Value - 7501" => 2, "Invoice Value - Contract" => 4,
       "Unit Price - Brand" => 7, "Unit Price - PO" => 6, "Unit Price - 7501" => BigDecimal(2.0/3,6)})                                  
  end

  it "returns expected results when products are linked by reference number" do
    @p.update_attributes(unique_identifier: "foo")

    result = report.run_query @cdefs
    expect(result.count).to eq 1
    expect(result.first).to eq(
      {"Invoice Value - Brand" => 21, "Invoice Value - 7501" => 2, "Invoice Value - Contract" => 4,
       "Unit Price - Brand" => 7, "Unit Price - PO" => 6, "Unit Price - 7501" => BigDecimal(2.0/3,6)})                                  
  end

  context "Invoice Value - Contract" do
    it "returns invoice value if contract amount isn't greater than 0" do
      @cil.update_attributes(contract_amount: 0)
      result = report.run_query @cdefs
      expect(result.first["Invoice Value - Contract"]).to eq 2
    end
  end
end