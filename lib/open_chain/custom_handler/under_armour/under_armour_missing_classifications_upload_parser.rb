require 'open_chain/custom_handler/custom_file_csv_excel_parser'
require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'
require 'open_chain/mutable_boolean'

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

  def process user
    begin
      process_file @custom_file, user
      user.messages.create subject: "File Processing Complete", body: "Missing Classifications Upload processing for file #{@custom_file.attached_file_name} is complete."
    rescue => e
      user.messages.create(:subject=>"File Processing Complete With Errors", :body=>"Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}")
    end
    nil
  end

  def process_file custom_file, user
    codes = DataCrossReference.where(cross_reference_type: 'ua_site').pluck(:key)
    missing_codes = {}
    filename = custom_file.attached_file_name
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
    prod_hsh = init_hsh(rows.first[0]) # prime the pump
    rows.each_with_index do |row, i|
      if row[7].present? && !codes.include?(row[7])
        missing_codes[i + 1] = row[7]
        next
      end
      if prod_hsh[:unique_identifier] == row[0]
        load_hsh prod_hsh, row
      else
        update_product prod_hsh unless prod_hsh[:record_count].zero?        
        prod_hsh = init_hsh
        load_hsh prod_hsh, row        
      end
    end
    update_product prod_hsh unless prod_hsh[:record_count].zero?
  end

  def init_hsh uid=nil
    {unique_identifier: uid, import_countries: [], site_codes: [], style: nil, color: nil, size_code: nil, size_description: nil, record_count: 0}
  end

  def update_product prod_hsh
    changed = MutableBoolean.new(false)
    Lock.acquire("Product-#{prod_hsh[:unique_identifier]}") do
      p = Product.where(unique_identifier: prod_hsh[:unique_identifier]).first_or_initialize(unique_identifier: prod_hsh[:unique_identifier])
      set_multi_value_field p, cdefs[:prod_import_countries], prod_hsh[:import_countries], changed
      set_multi_value_field p, cdefs[:prod_site_codes], prod_hsh[:site_codes], changed
      set_single_value_fields p, cdefs, prod_hsh if !p.persisted?
      if !p.persisted? || changed.value
        p.save!
        p.create_snapshot User.integration, nil, "UA Missing Classification Upload Parser"
      end
    end
  end

  def load_hsh hsh, row
    hsh[:unique_identifier] = row[0]
    hsh[:name] = row[1]
    hsh[:import_countries] << row[2]
    hsh[:style] = row[3]
    hsh[:color] = row[4]
    hsh[:size_code] = row[5]
    hsh[:size_description] = row[6]
    hsh[:site_codes] << row[7]
    hsh[:record_count] += 1
  end

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

  def set_multi_value_field product, cdef, prod_hsh_field, changed
    old_val = product.custom_value(cdef).try(:split,"\n ").try(:sort) || []
    new_val = (old_val + prod_hsh_field).compact.try(:sort).try(:uniq)
    if old_val != new_val
      product.find_and_set_custom_value(cdef, new_val.join("\n "))
      changed.value = true
    end
  end

  def set_single_value_fields product, cdefs, prod_hsh
    product.name = prod_hsh[:name]
    product.find_and_set_custom_value(cdefs[:prod_style], prod_hsh[:style])
    product.find_and_set_custom_value(cdefs[:prod_color], prod_hsh[:color])
    product.find_and_set_custom_value(cdefs[:prod_size_code], prod_hsh[:size_code])
    product.find_and_set_custom_value(cdefs[:prod_size_description], prod_hsh[:size_description])    
  end

end; end; end; end;