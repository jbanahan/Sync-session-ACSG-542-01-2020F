require 'open_chain/custom_handler/custom_file_to_imported_file_passthrough_handler'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberProductUploadHandler
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::CustomHandler::CustomFileToImportedFilePassthroughHandler

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.valid_file? file
    [".xls", ".xlsx", ".csv"].include? File.extname(file).to_s.downcase
  end

  def self.can_view? user
    return MasterSetup.get.custom_feature?('Lumber EPD') &&
            user.company.master? && user.edit_products?
  end

  def can_view? user
    self.class.can_view? user
  end

  def process user
    begin
      process_file @custom_file, user, skip_headers: false
    rescue => e
      user.messages.create(:subject=>"File Processing Complete With Errors", :body=>"Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}")
    end
    nil
  end

  def translate_file_line line
    # The very first line coming in here is expected to be the headers, use it to determine the layout type.
    # Then we can throw it away.
    rows = []
    if layout_type.nil?
      identify_file_layout(line)
    elsif layout_type == :canada
      rows << translate_canada_file_line(line)
    elsif layout_type == :us
      rows << translate_us_file_line(line)
    end

    rows
  end

  def identify_file_layout headers
    # US Upload has 4 columns, CA has 12

    # Strip any blank trailing information from the file
    headers = headers.map {|v| v.to_s.blank? ? nil : v.to_s }.compact
    layout_type = headers.length == 12 ? :canada : ( headers.length == 4 ? :us : nil )
    raise "Unable to determine file layout.  All files must have a header row. US files must have 4 columns. CA files must have 12 columns." unless layout_type
    @layout_type = layout_type
    nil
  end

  def layout_type
    @layout_type
  end

  def translate_canada_file_line line
    @ca ||= Country.where(iso_code: "CA").first

    row = []
    row << lumber_system_code # Importer System code
    row << normalize_article_number(line[4]) # Article Number

    row << "CA" # Classification Country
    row << line[6] # Classification Customs Description
    hts = text_value(line[10]).to_s.strip.gsub(".", "")
    row << hts # Proposed HTS

    # Validate that the hts number is valid.....we don't want the file import to reject the whole line just because
    # the tariff is bad (which is the way imported files works).  So validate it ahead of time and strip it from the file if it's
    # bad.
    if OfficialTariff.valid_hts? @ca, hts
      row << hts # Tarriff - HTS 1
    else
      row << nil
    end

    row << 1 # Row Number

    row
  end

  def translate_us_file_line line
    @us ||= Country.where(iso_code: "US").first
    row = []
    row << lumber_system_code # Importer System code
    row << normalize_article_number(line[0]) # Article Number
    row << text_value(line[2]) # Old Article Number

    # If there's no hts present on the line, there's no point in adding any more fields to the translation
    row << "US" # Classification Country
    hts = text_value(line[3]).to_s.strip.gsub(".", "")
    row << hts # Proposed HTS
    # Validate that the hts number is valid.....we don't want the file import to reject the whole line just because
    # the tariff is bad (which is the way imported files works).  So validate it ahead of time and strip it from the file if it's
    # bad.
    if OfficialTariff.valid_hts? @us, hts
      row << hts # Tarriff - HTS 1
    else
      row << nil
    end

    row << 1 # Row Number

    row
  end

  def normalize_article_number article_num
    text_value(article_num).to_s.strip.rjust(18, '0')
  end

  def lumber_system_code
    @lumber ||= Company.where(master: true).first
    raise "A system code must be associated with the Lumber Liquidators master company account." if @lumber.try(:system_code).blank?

    @lumber.system_code
  end

  def search_setup_attributes file, user
    {name: search_name(), user_id: user.id, module_type: "Product"}
  end

  def search_column_uids
    layout_type == :us ? us_search_column_uids : ca_search_column_uids
  end

  def ca_search_column_uids
    @cdefs ||= self.class.prep_custom_definitions [:class_proposed_hts, :class_customs_description]
    [:prod_imp_syscode, :prod_uid, :class_cntry_iso, @cdefs[:class_customs_description].model_field_uid, @cdefs[:class_proposed_hts].model_field_uid, :hts_hts_1, :hts_line_number]
  end

  def us_search_column_uids
    @cdefs ||= self.class.prep_custom_definitions [:prod_old_article, :class_proposed_hts]
    [:prod_imp_syscode, :prod_uid, @cdefs[:prod_old_article].model_field_uid, :class_cntry_iso, @cdefs[:class_proposed_hts].model_field_uid, :hts_hts_1, :hts_line_number]
  end

  def search_name
    layout_type == :canada ? "CA Parts Upload (Do Not Delete or Modify)" : "US Parts Upload (Do Not Delete or Modify)"
  end

  def generate_imported_file file, user
    search_setup = find_or_create_search_setup file, user
    imported_file = search_setup.imported_files.build update_mode: "update", starting_row: 1, starting_column: 1, module_type: search_setup.module_type, user_id: user.id
    imported_file.attached = file
    imported_file.save!

    imported_file
  end
end; end; end; end