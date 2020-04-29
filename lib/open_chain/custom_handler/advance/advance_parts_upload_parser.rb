require 'open_chain/custom_handler/custom_file_to_imported_file_passthrough_handler'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Advance; class AdvancePartsUploadParser
  include OpenChain::CustomHandler::CustomFileToImportedFilePassthroughHandler
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("Advance 7501") && user.company.master? && user.edit_products?
  end

  def can_view? user
    self.class.can_view? user
  end

  # What we're going to do here is take the uploaded file - which contains 1 line per product.
  # We'll then expload that out into multiple lines (1 for ADVAN and one for CQ) and then map
  # this new file BACK into an imported file and process it.
  #
  # We're doing this so that the user gets the benefits of the imported file logs / screen / error reporting
  # with the flexibility of a custom upload.
  def process user
    @cdefs = self.class.prep_custom_definitions [:prod_part_number, :prod_short_description, :prod_units_per_set, :class_customs_description, :prod_sku_number]
    begin
      process_file @custom_file, user, skip_headers: true
    rescue => e
      user.messages.create(:subject=>"File Processing Complete With Errors", :body=>"Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}")
    end
    nil
  end

  def translate_file_line line
    lines = []

    # If there's a value in column 0 it means this part should be listed in the ADVAN file
    if !line[0].blank?
      advan = []
      advan << "ADVAN" # Importer Syscode
      advan << "ADVAN-#{text_value(line[0])}" # Unique Identifier
      advan << text_value(line[0]) # Part Number
      advan << "" # Sku Number
      advan << text_value(line[1]) # Short Description
      advan << text_value(line[8]) # Name
      advan << decimal_value(line[14], decimal_places: 0) # Units Per Set
      advan << "US" # Country ISO
      advan << "" # Customs Description (CA Only)
      advan << text_value(line[9]) # First HTS 1 (US)
      advan << text_value(line[11]) # First HTS 1 (CA)
      advan << boolean_value(line[15]) # Part Inactive

      lines << advan
    end

    # If there's a value in column 3 it means this part should be listed as a CQ file
    if !line[3].blank?
      cq = []
      cq << "CQ" # Importer Syscode
      cq << "CQ-#{text_value(line[3])}" # Unique Identifier
      cq << text_value(line[3]) # Part Number
      cq << text_value(line[0]) # Sku Number
      cq << text_value(line[1]) # Short Description
      cq << text_value(line[8]) # Name
      cq << decimal_value(line[14], decimal_places: 0) # Units Per Set
      cq << "CA" # Country ISO
      cq << line[8] # Customs Description
      cq << text_value(line[9]) # First HTS 1 (US)
      cq << text_value(line[11]) # First HTS 1 (CA)
      cq << boolean_value(line[15]) # Part Inactive

      lines << cq
    end


    lines
  end

  def search_setup_attributes file, user
    {name: "ADVAN/CQ Parts Upload (Do Not Delete or Modify!)", user_id: user.id, module_type: "Product"}
  end

  def search_column_uids
    @ca ||= "*fhts_1_#{Country.where(iso_code: "CA").first.id}"
    @us ||= "*fhts_1_#{Country.where(iso_code: "US").first.id}"
    # Validate that @CA and @US are model fields..
    raise ArgumentError, "The field 'First HTS 1 (CA)' is not set up as part of the imported file setup." if ModelField.find_by_uid(@ca).blank?
    raise ArgumentError, "The field 'First HTS 1 (US)' is not set up as part of the imported file setup." if ModelField.find_by_uid(@us).blank?

    [:prod_imp_syscode, :prod_uid, @cdefs[:prod_part_number].model_field_uid, @cdefs[:prod_sku_number].model_field_uid, @cdefs[:prod_short_description].model_field_uid, :prod_name, @cdefs[:prod_units_per_set].model_field_uid, :class_cntry_iso, @cdefs[:class_customs_description].model_field_uid, @us, @ca, :prod_inactive]
  end


end; end; end; end
