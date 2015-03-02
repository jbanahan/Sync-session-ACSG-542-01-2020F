require 'open_chain/report/report_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module Report; class PoloMissingHtsReport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.run_schedulable opts = {}
    emails = opts['email_to']
    tz = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    start_date = Time.zone.now.in_time_zone(tz).to_date
    end_date = (Time.zone.now + 1.month).in_time_zone(tz).to_date

    self.new.run start_date, end_date, emails
  end

  def run ex_factory_start, ex_factory_end, emails
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number, :ord_line_ex_factory_date, :ord_division]
    qry = query(ex_factory_start, ex_factory_end)

    wb = XlsMaker.create_workbook 'Missing CA HTS Report'
    sheet = wb.worksheets[0]
    rows = table_from_query sheet, qry
    if rows == 0
      XlsMaker.add_body_row sheet, 1, ["No Styles missing CA HTS values."]
    end

    workbook_to_tempfile(wb, "Missing CA HTS Report", file_name: "Missing CA HTS Report #{ex_factory_start} - #{ex_factory_end}.xls") do |t|
      OpenMailer.send_simple_html(emails, "[VFI Track] Missing CA HTS Report - #{ex_factory_start}", "The attached report lists all the styles missing Canadian HTS values with #{@cdefs[:ord_line_ex_factory_date].label} values between #{ex_factory_start} and #{ex_factory_end}.".html_safe, [t]).deliver!
    end
  end

  def query ex_factory_start, ex_factory_end
    @ca ||= Country.where(iso_code: "CA").first
    # The case statement in the middle handles stripping the last 3 chars from the style when it's a prepack - RL appends the pack code the 
    # style for prepacks for some reason, which means the order style doesn't match to the actual product style 
    "SELECT o.customer_order_number as 'Order Number', cv.string_value as 'Style', ex.date_value as 'Ex-Factory Date', merch.string_value as 'Merchandise Division'
FROM orders o
LEFT OUTER JOIN custom_values merch ON merch.custom_definition_id = #{@cdefs[:ord_division].id} and merch.customizable_id = o.id and merch.customizable_type = 'Order'
INNER JOIN companies i on o.importer_id = i.id and i.fenix_customer_number in ('806167003RM0001', '866806458RM0001') and i.importer = 1
INNER JOIN order_lines l ON l.order_id = o.id
INNER JOIN custom_values ex ON ex.custom_definition_id = #{@cdefs[:ord_line_ex_factory_date].id} and ex.customizable_id = l.id and ex.customizable_type = 'OrderLine'
INNER JOIN products p ON l.product_id = p.id
INNER JOIN custom_values cv ON cv.custom_definition_id = #{@cdefs[:prod_part_number].id} and cv.customizable_id = p.id and cv.customizable_type = 'Product'
LEFT OUTER JOIN products p2 ON p2.unique_identifier = concat('RLMASTER-', (case p.unit_of_measure WHEN 'AS' THEN substring(cv.string_value, 1, (length(cv.string_value) - 3)) ELSE cv.string_value END))
LEFT OUTER JOIN classifications c ON p2.id = c.product_id and c.country_id = #{@ca.id}
LEFT OUTER JOIN tariff_records t ON t.classification_id = c.id and t.hts_1 <> ''
LEFT OUTER JOIN official_tariffs ot ON t.hts_1 = ot.hts_code AND ot.country_id = c.country_id
WHERE ot.hts_code IS NULL AND ex.date_value >= '#{ex_factory_start}' and ex.date_value <= '#{ex_factory_end}'
ORDER BY ex.date_value ASC, o.customer_order_number, cv.string_value"
  end

end; end; end;