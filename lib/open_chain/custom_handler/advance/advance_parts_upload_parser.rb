require 'open_chain/custom_handler/custom_file_csv_excel_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Advance; class AdvancePartsUploadParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("alliance") && user.company.master? && user.edit_products?
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
      process_file @custom_file, user
    rescue ArgumentError => e
      user.messages.create(:subject=>"File Processing Complete With Errors", :body=>"Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}")
    end
    nil
  end

  def process_file custom_file, user
    new_filename = [File.basename(custom_file.path, ".*"), ".csv"]
    imported_file = nil
    Tempfile.open(new_filename) do |outfile|
      Attachment.add_original_filename_method outfile, new_filename.join

      foreach(custom_file, skip_headers: true, skip_blank_lines: true) do |row|
        lines = translate_file_line row
        lines.each {|line|  outfile << line.to_csv } 
      end
      outfile.flush
      outfile.rewind

      imported_file = generate_imported_file outfile, user
    end

    imported_file.process user
  end


  def translate_file_line line
    lines = []

    # If there's a value in column 0 it means this part should be listed in the ADVAN file
    if !line[0].blank?
      advan = []
      advan << "ADVAN" # Importer Syscode
      advan << "ADVAN-#{text_value(line[0])}" #Unique Identifier
      advan << text_value(line[0]) # Part Number
      advan << "" # Sku Number
      advan << text_value(line[1]) # Short Description
      advan << text_value(line[8]) # Name
      advan << decimal_value(line[14], decimal_places: 0) # Units Per Set
      advan << "US" # Country ISO
      advan << "" # Customs Description (CA Only)
      advan << text_value(line[9]) # First HTS 1 (US)
      advan << text_value(line[11]) # First HTS 1 (CA)
      
      lines << advan
    end

    # If there's a value in column 3 it means this part should be listed as a CQ file
    if !line[3].blank?
      cq = []
      cq << "CQ" # Importer Syscode
      cq << "CQ-#{text_value(line[3])}" #Unique Identifier
      cq << text_value(line[3]) # Part Number
      cq << text_value(line[0]) # Sku Number
      cq << text_value(line[1]) # Short Description
      cq << text_value(line[8]) # Name
      cq << decimal_value(line[14], decimal_places: 0) # Units Per Set
      cq << "CA" # Country ISO
      cq << line[8] # Customs Description
      cq << text_value(line[9]) # First HTS 1 (US)
      cq << text_value(line[11]) # First HTS 1 (CA)
      
      lines << cq
    end


    lines
  end


  def generate_imported_file file, user
    search_setup = find_or_create_search_setup user
    imported_file = search_setup.imported_files.build update_mode: "any", starting_row: 1, starting_column: 1, module_type: search_setup.module_type, user_id: user.id
    imported_file.attached = file
    imported_file.save!

    imported_file
  end

  def find_or_create_search_setup user
    attrs = {name: "ADVAN/CQ Parts Upload (Do Not Delete or Modify!)", user_id: user.id, module_type: "Product"}
    search_setup = SearchSetup.where(attrs).first
    if search_setup
      validate_search_setup(search_setup)
    else
      search_setup = create_search_setup attrs
    end

    search_setup
  end

  def validate_search_setup search_setup
    # All we need to do is verify that the expected search columns are in the right order
    columns = search_setup.search_columns.sort {|a, b| a.rank <=> b.rank }
    column_uids.each_with_index do |uid, x|
      if columns[x].nil? || columns[x].model_field_uid.to_s != uid.to_s
        expected_model_field_label = ModelField.find_by_uid(uid).label

        actual_model_field_label = columns[x].nil? ? "blank" : ModelField.find_by_uid(columns[x].model_field_uid.to_s).label

        raise ArgumentError, "Expected to find the field '#{expected_model_field_label}' in column #{x + 1}, but found field '#{actual_model_field_label}' instead."
      end
    end
  end

  def create_search_setup setup_attributes
    setup = SearchSetup.new setup_attributes
    column_uids.each_with_index do |uid, x|
      setup.search_columns.build rank: x, model_field_uid: uid.to_s
    end
    setup.save!
    setup
  end

  def column_uids
    @ca ||= "*fhts_1_#{Country.where(iso_code: "CA").first.id}"
    @us ||= "*fhts_1_#{Country.where(iso_code: "US").first.id}"
    # Validate that @CA and @US are model fields..
    raise ArgumentError, "The field 'First HTS 1 (CA)' is not set up as part of the imported file setup." if ModelField.find_by_uid(@ca).blank?
    raise ArgumentError, "The field 'First HTS 1 (US)' is not set up as part of the imported file setup." if ModelField.find_by_uid(@us).blank?

    [:prod_imp_syscode, :prod_uid,  @cdefs[:prod_part_number].model_field_uid, @cdefs[:prod_sku_number].model_field_uid, @cdefs[:prod_short_description].model_field_uid, :prod_name, @cdefs[:prod_units_per_set].model_field_uid, :class_cntry_iso, @cdefs[:class_customs_description].model_field_uid, @us, @ca]
  end


end; end; end; end