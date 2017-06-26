require 'open_chain/custom_handler/custom_file_csv_excel_parser'
require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'

module OpenChain; module CustomHandler; module UnderArmour; class UnderArmourMissingClassificationsUploadParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser
  include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport

  ERROR_EMAIL = 'jkohn@vandegriftinc.com'

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.valid_file? filename
    ['.XLS','.XLSX', '.CSV'].include? File.extname(filename.upcase)
  end

  def process user, filename
    codes = DataCrossReference.where(cross_reference_type: 'ua_site').pluck(:key)
    missing_codes = {}
    data = foreach @custom_file
    parse data.drop(1), codes, missing_codes, filename
    send_email missing_codes, filename unless missing_codes.empty?
  end

  def can_view? user
    user.company.master? && user.edit_products? && MasterSetup.get.custom_feature?('UA SAP')
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_import_countries, :prod_style, :prod_color, :prod_size_code, :prod_size_description, :prod_site_codes]
  end

  def parse rows, codes, missing_codes, filename
    rows.each_with_index do |row, i|
      if row[7].presence && !codes.include?(row[7])
        missing_codes[i + 1] = row[7]
        next
      end
      Lock.acquire("Product-#{row[0]}") do
        p = Product.where(unique_identifier: row[0]).first_or_initialize(unique_identifier: row[0])
        set_multi_value_field p, cdefs[:prod_import_countries], row[2]
        set_multi_value_field p, cdefs[:prod_site_codes], row[7]
        set_single_value_fields p, cdefs, row if !p.persisted?
        p.save!
      end
    end
  end

  private

  def send_email codes_hsh, filename
    body = error_string(codes_hsh, filename)
    OpenMailer.send_simple_html(ERROR_EMAIL, "Missing Classifications Upload Error", body).deliver!
  end

  def error_string codes_hsh, filename
    start = "The following site codes in #{filename} were unrecognized: ".html_safe
    middle = codes_hsh.map{ |row_num, code| "#{code} (row #{row_num})"}.join(", ")
    ending = %Q(<br><br>Please add it to the <a href="#{url}">list</a> and try again.).html_safe
    start + middle + ending
  end

  def url
    Rails.application.routes.url_helpers.data_cross_references_url(cross_reference_type: 'ua_site', host: MasterSetup.get.request_host, protocol: (Rails.env.development? ? "http" : "https"))
  end

  def set_multi_value_field product, cdef, row_field
    val = product.custom_value(cdef).try(:split,"\n ") || []
    if !val.include? row_field
      product.find_and_set_custom_value(cdef, (val << row_field).join("\n "))
    end
  end

  def set_single_value_fields product, cdefs, row
    product.name = row[1]
    product.find_and_set_custom_value(cdefs[:prod_style], row[3])
    product.find_and_set_custom_value(cdefs[:prod_color], row[4])
    product.find_and_set_custom_value(cdefs[:prod_size_code], row[5])
    product.find_and_set_custom_value(cdefs[:prod_size_description], row[6])    
  end

end; end; end; end;