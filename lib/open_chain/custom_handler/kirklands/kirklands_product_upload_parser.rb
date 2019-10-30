require 'open_chain/custom_handler/custom_file_to_imported_file_passthrough_handler'
require 'open_chain/custom_handler/kirklands/kirklands_custom_definition_support'
require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module Kirklands; class KirklandsProductUploadParser
  include OpenChain::CustomHandler::CustomFileToImportedFilePassthroughHandler
  include OpenChain::CustomHandler::Kirklands::KirklandsCustomDefinitionSupport

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.valid_file? file
    [".xls", ".xlsx", ".csv"].include? File.extname(file).to_s.downcase
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("Kirklands") && user.company.master? && user.edit_products?
  end

  def can_view? user
    self.class.can_view? user
  end

  def process user
    begin
      process_file @custom_file, user, skip_headers: true
    rescue => e
      user.messages.create(:subject=>"File Processing Complete With Errors", :body=>"Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}")
    end
    nil
  end

  def translate_file_line line
    row = []

    row << "KLANDS"

    row << text_value(line[0]) # Product unique identifier "Kirklands item number"
    row << text_value(line[1]) # Part number "Vendor item number"
    row << text_value(line[2]) # Product description long
    row << text_value(line[3]) # Material
    row << text_value(line[4]) # Country of origin
    row << boolean_value(line[5]) # additional docs requirement?
    row << decimal_value(line[6]) # FOB price
    row << text_value(line[7]) # HTS code 1

    row << text_value(line[8]) # MTB HTS code 2

    row << boolean_value(line[9]) # fda?
    row << text_value(line[10]) # fda product code
    row << boolean_value(line[11]) # tsca?
    row << boolean_value(line[12]) # lacey?
    row << boolean_value(line[13]) # add?
    row << text_value(line[14]) # add case number
    row << boolean_value(line[15]) # cvd?
    row << text_value(line[16]) # cvd case number
    row << 1 # single line tariffs
    row << "US"

    row
  end

  def search_column_uids
    @cdefs ||= self.class.prep_custom_definitions [ :prod_part_number, :prod_material, :prod_country_of_origin, :prod_additional_doc,
      :prod_fob_price, :prod_fda_product, :prod_fda_code, :prod_tsca, :prod_lacey, :prod_add, :prod_add_case, :prod_cvd, :prod_cvd_case ]

    [ :prod_imp_syscode,
      :prod_uid,
      @cdefs[:prod_part_number].model_field_uid,
      :prod_name,
      @cdefs[:prod_material].model_field_uid,
      @cdefs[:prod_country_of_origin].model_field_uid,
      @cdefs[:prod_additional_doc].model_field_uid,
      @cdefs[:prod_fob_price].model_field_uid,
      :hts_hts_1,
      :hts_hts_2,
      @cdefs[:prod_fda_product].model_field_uid,
      @cdefs[:prod_fda_code].model_field_uid,
      @cdefs[:prod_tsca].model_field_uid,
      @cdefs[:prod_lacey].model_field_uid,
      @cdefs[:prod_add].model_field_uid,
      @cdefs[:prod_add_case].model_field_uid,
      @cdefs[:prod_cvd].model_field_uid,
      @cdefs[:prod_cvd_case].model_field_uid,
      :hts_line_number,
      :class_cntry_iso ]
  end

  def search_setup_attributes file, user
    {name: "Kirklands Products Upload (Do Not Delete or Modify!)", user_id: user.id, module_type: "Product"}
  end
end; end; end; end
