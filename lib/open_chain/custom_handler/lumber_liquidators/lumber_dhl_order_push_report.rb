require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberDhlOrderPushReport
  include LumberCustomDefinitionSupport
  include OpenChain::Report::ReportHelper

  def self.run_report(user, settings = {})
    self.new.run_report user
  end

  def self.permission? user
    MasterSetup.get.system_code == "ll" && user.in_group?("LOGISTICS")
  end

  def initialize
    @cdefs = self.class.prep_custom_definitions [:ord_country_of_origin, :ord_dhl_push_date]
  end

  def run_report user
    wb = create_report
    update_orders @order_ids, user
    workbook_to_tempfile wb, "DHL PO Push", file_name: "DHL PO Push #{Time.zone.now.in_time_zone(user.time_zone).to_date.strftime  '%m-%d-%y'}.xls"
  end

  def create_report
    wb, sheet = XlsMaker.create_workbook_and_sheet "DHL PO Push", nil
    table_from_query sheet, query(['BO', 'BR', 'PE', 'PY', 'CO']), conversions, query_column_offset: 1
    wb
  end

  def query countries
    <<-QRY
      SELECT o.id 'ID', o.order_number 'Order Number', c.name 'Vendor Name'
      FROM orders o
      LEFT OUTER JOIN companies c on c.id = o.vendor_id
      INNER JOIN custom_values v on o.id = v.customizable_id AND v.customizable_type = 'Order' AND v.custom_definition_id = #{@cdefs[:ord_country_of_origin].id} AND v.string_value IN (#{countries.map {|c| ActiveRecord::Base.sanitize c}.join ","})
      INNER JOIN business_validation_results r on o.id = r.validatable_id AND r.validatable_type = 'Order' AND r.state = 'Pass'
      LEFT OUTER JOIN custom_values d on o.id = d.customizable_id AND d.customizable_type = 'Order' AND d.custom_definition_id = #{@cdefs[:ord_dhl_push_date].id}
      WHERE o.closed_at IS NULL AND length(trim(ifnull(o.approval_status, ''))) > 0 AND d.date_value IS NULL
    QRY
  end

  def update_orders ids, user
    orders = Order.find ids
    date = Time.zone.now.in_time_zone(user.time_zone).to_date
    integration = User.integration

    orders.each do |order|
      order.update_custom_value! @cdefs[:ord_dhl_push_date], date
      order.create_snapshot integration, nil, "System Job: DHL Order Push Report"
    end
  end

  def conversions
    @order_ids = []
    conv = {}
    conv['ID'] = lambda {|row, value| @order_ids << value }

    conv
  end


end; end; end; end
