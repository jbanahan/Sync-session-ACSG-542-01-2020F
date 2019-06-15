require 'open_chain/report/report_helper'

module OpenChain; module Report; class StaleTariffs
  include OpenChain::Report::ReportHelper
  
  def self.permission? user
    user.company.master? && user.view_products?
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end
  
  def self.run_schedulable settings={}
    self.new.send_email settings
  end

  def run run_by, settings={}
    countries, importer_ids = extract_settings settings
    wb = create_workbook countries, importer_ids
    xlsx_workbook_to_tempfile wb, "stale_tariffs"
  end

  def send_email settings
    countries, importer_ids, email = extract_settings settings
    wb = create_workbook countries, importer_ids
    name = "Stale Tariffs Report #{ ActiveSupport::TimeZone["Eastern Time (US & Canada)"].today.strftime("%Y-%m") }"
    xlsx_workbook_to_tempfile wb, '', file_name: "#{name}.xlsx" do |t|
      subject = name
      body = "<p>Report attached.<br>--This is an automated message, please do not reply.<br>This message was generated from VFI Track</p>".html_safe
      OpenMailer.send_simple_html(email, subject, body, t).deliver_now
    end
  end

  def ids_from_customer_numbers customer_numbers
    codes = customer_numbers.is_a?(String) ? customer_numbers.split("\n").map{ |c| c.strip.presence }.compact : Array.wrap(customer_numbers)
    Company.where(system_code: codes).map(&:id) if codes.present?
  end
  
  private
  
  def extract_settings settings
    countries = settings["countries"]
    importer_ids = settings["importer_ids"] || ids_from_customer_numbers(settings["customer_numbers"])
    email = settings["email"]
    [countries, importer_ids, email]
  end

  def create_workbook countries=nil, importer_ids=nil
    wb = XlsxBuilder.new
    
    {"hts_1" => "HTS #1", "hts_2" => "HTS #2", "hts_3" => "HTS #3"}.each_pair do |field, name|
      sheet = wb.create_sheet("Stale Tariffs #{name}")
      wb.add_header_row sheet, [ModelField.find_by_uid(:cmp_name).label,
                                 ModelField.find_by_uid(:prod_uid).label,
                                 ModelField.find_by_uid(:class_cntry_name).label,
                                 name]

      row_cursor = 1
      result = get_query_result(field, countries, importer_ids)
      result.each do |result_row|
        row_content = []
        (0..3).each {|i| row_content.push result_row[i] }
        wb.add_body_row sheet, row_content
        row_cursor += 1
      end

      if row_cursor ==1 #we haven't written any records
        wb.add_body_row sheet, ["Congratulations! You don't have any stale tariffs."]
      end
    end
    wb
  end

  def get_query_result(hts_field, countries, importer_ids)
    sql = base_query hts_field

    if countries.try(:length).to_i > 0
      sql += " AND ctr.iso_code IN (" + countries.map {|c| ActiveRecord::Base.sanitize c }.join(", ") + ")"
    end

    if importer_ids.try(:length).to_i > 0
      sql += " AND p.importer_id IN (" + importer_ids.map {|i| i.to_i}.join(", ") + ")"
    end

    sql += " ORDER BY ctr.name, comp.name, tr.#{hts_field}, p.unique_identifier"

    TariffRecord.connection.execute(sql)
  end

  def base_query hts_field
    <<-SQL
      SELECT comp.name, p.unique_identifier, ctr.name, tr.#{hts_field}
      FROM tariff_records tr
        INNER JOIN classifications c ON tr.classification_id = c.id
        INNER JOIN countries ctr ON ctr.id = c.country_id
        INNER JOIN products p ON c.product_id = p.id
        LEFT OUTER JOIN companies comp ON comp.id = p.importer_id 
        LEFT OUTER JOIN official_tariffs ot ON c.country_id = ot.country_id AND tr.#{hts_field} = ot.hts_code
      WHERE ot.id IS NULL AND tr.#{hts_field} IS NOT NULL AND LENGTH(tr.#{hts_field}) > 0
    SQL
  end

end; end; end
