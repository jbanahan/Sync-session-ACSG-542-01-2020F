require 'open_chain/report/builder_output_report_helper'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'

module OpenChain; module CustomHandler; module AnnInc; class AnnFtzErrorReport
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
  include OpenChain::Report::BuilderOutputReportHelper

  TEMPLATE_SYS_CODE = "FTZ"

  # required settings: {"distribution_list": <string>}
  def self.run_schedulable settings={}
    self.new.run_report settings
  end

  def run_report settings
    wb = create_workbook(settings["template_system_code"])
    dist_list = MailingList.where(system_code: settings["distribution_list"]).first
    send_email wb, dist_list
  end

  def send_email wb, mailing_list
    today = Time.zone.now.in_time_zone("America/New_York").to_date.strftime("%Y-%m-%d")
    write_builder_to_tempfile wb, "Ann_FTZ_Error_Report_#{today}" do |t|
      body = "The Ann FTZ Error Report for #{today} is attached."
      OpenMailer.send_simple_html(mailing_list, "Ann FTZ Error Report #{today}", body, t).deliver_now!
    end
  end

  def create_workbook template_system_code
    wb = XlsxBuilder.new
    sheet = wb.create_sheet "Rule Failures"
    write_query_to_builder wb, sheet, query(template_system_code), data_conversions: conversions(wb)
    wb
  end

  def conversions builder
    {"Link to VFI Track" => weblink_translation_lambda(builder, Product),
     "Manual Entry Processing" => boolean_translation_lambda}
  end

  def boolean_translation_lambda
    lambda { |*, raw_column_value| (raw_column_value.to_i == 1).to_s }
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:related_styles, :approved_date, :manual_flag, :classification_type, :percent_of_value, :key_description]
  end

  def query template_system_code
    <<-SQL
      SELECT p.unique_identifier AS "Style",
             related_styles.text_value AS "Related Styles",
             approved_date.date_value AS "Approved Date",
             manual_flag.boolean_value AS "Manual Entry Processing",
             classification_type.string_value AS "Classification Type",
             tr.hts_1 AS "HTS Value",
             percent_of_value.integer_value AS "Percent of Value",
             key_description.text_value AS "Key Description",
             u.username AS "Last User to Alter the Record",
             bvrr.message AS "Business Rule Failure Message",
             p.id AS "Link to VFI Track"
      FROM products p
        LEFT OUTER JOIN custom_values related_styles ON related_styles.customizable_id = p.id
          AND related_styles.customizable_type = "Product" AND related_styles.custom_definition_id = #{cdefs[:related_styles].id}
        INNER JOIN classifications cl ON p.id = cl.product_id
        LEFT OUTER JOIN custom_values approved_date ON approved_date.customizable_id = cl.id
          AND approved_date.customizable_type = "Classification" AND approved_date.custom_definition_id = #{cdefs[:approved_date].id}
        LEFT OUTER JOIN custom_values manual_flag ON manual_flag.customizable_id = cl.id
          AND manual_flag.customizable_type = "Classification" AND manual_flag.custom_definition_id = #{cdefs[:manual_flag].id}
        LEFT OUTER JOIN custom_values classification_type ON classification_type.customizable_id = cl.id
          AND classification_type.customizable_type = "Classification" AND classification_type.custom_definition_id = #{cdefs[:classification_type].id}
        INNER JOIN tariff_records tr ON cl.id = tr.classification_id
        LEFT OUTER JOIN custom_values percent_of_value ON percent_of_value.customizable_id = tr.id
          AND percent_of_value.customizable_type = "TariffRecord" AND percent_of_value.custom_definition_id = #{cdefs[:percent_of_value].id}
        LEFT OUTER JOIN custom_values key_description ON key_description.customizable_id = tr.id
          AND key_description.customizable_type = "TariffRecord" AND key_description.custom_definition_id = #{cdefs[:key_description].id}
        LEFT OUTER JOIN users u ON p.last_updated_by_id = u.id
        INNER JOIN business_validation_results bvre ON p.id = bvre.validatable_id AND bvre.validatable_type = "Product"
        INNER JOIN business_validation_rule_results bvrr ON bvre.id = bvrr.business_validation_result_id
        INNER JOIN business_validation_templates bvt ON bvt.id = bvre.business_validation_template_id
      WHERE bvt.system_code = "#{TEMPLATE_SYS_CODE}" AND bvrr.state <> "Pass"
    SQL
  end

end; end; end; end
