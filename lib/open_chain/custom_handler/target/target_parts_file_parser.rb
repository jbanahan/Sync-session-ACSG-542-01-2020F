require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/csv_file_parser_support'
require 'open_chain/custom_handler/change_tracking_parser_support'
require 'open_chain/custom_handler/target/target_support'
require 'open_chain/custom_handler/target/target_custom_definition_support'

module OpenChain; module CustomHandler; module Target; class TargetPartsFileParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::CsvFileParserSupport
  include OpenChain::CustomHandler::ChangeTrackingParserSupport
  include OpenChain::CustomHandler::Target::TargetSupport
  include OpenChain::CustomHandler::Target::TargetCustomDefinitionSupport

  def self.parse data, opts = {}
    self.new.parse(data, opts)
  end

  def parse data, _opts = {}
    # We're going to get a single file that contains every part on an ASN, which shouldn't be that many lines / parts.
    part_lines = parse_csv_file(data, column_separator: "~", disable_quoting: true)
    pctl_row = find_row_type("PCTL", part_lines)
    return if pctl_row.blank?

    system_extract_time = source_timestamp(pctl_row)
    part_data = split_part_data_into_parts(part_lines)
    user = User.integration

    part_data.each do |lines|
      process_part_lines(lines, system_extract_time, user)
    end
    nil
  end

  def process_part_lines part_lines, source_system_time, user
    product_header = find_row_type("PHDR", part_lines)
    return if product_header.nil?

    find_or_create_product(product_header, source_system_time) do |product, new_product|
      changed = MutableBoolean.new false

      # These counters are used to determine how many records of each type were used so we can clear
      # any existing objects that might have been removed. Like if an affirmation of compliance / code was
      # removed.
      tariff_row_counters = Hash.new do |h, k|
        h[k] = Hash.new do |h2, k2|
          h2[k2] = Hash.new(0)
        end
      end
      sublines = []
      documents = Set.new
      cvd_add_indicators = Hash.new do |h, k|
        h[k] = Set.new
      end

      pdoc_lines = find_part_line_types(part_lines, "PDOC")
      process_product_header_line(product, product_header, changed)

      pdoc_lines.each do |line|
        document_type = process_required_documents_line(line)
        documents << document_type if document_type.present?
      end

      remapped_tariff_lines = create_tariff_line_remapping(find_part_line_types(part_lines, "PCLN"))
      remapped_tariff_lines.each_pair do |target_tariff_number, tariff_lines|
        process_classification_lines(product, target_tariff_number, tariff_lines, changed)
        set_tariff_counter_value(tariff_lines.first, tariff_row_counters, target_tariff_number)
      end

      preprocessed_records = Set.new(["PHDR", "PDOC", "PCLN", "PCTL"])
      part_lines.each do |line|
        rtype = row_type(line)
        next if preprocessed_records.include?(rtype)
        target_tariff_number = tariff_row_number(line)

        # Everything handled below here is linked to the tariff records...because of how Target sends funky
        # data w/ tariff data duplicated across multiple rows, they also send duplicate PGA data for all of these
        # too (which is crazy)  We're handling that above w/ the tariff remapping, and what that means
        # is that if we don't actually have a set of tariff lines in remapped_tariff_lines for the current
        # target tariff number, it means we can skip the line, because it's a duplicate.
        next if remapped_tariff_lines[target_tariff_number].nil?

        counter = set_tariff_counter_value(line, tariff_row_counters, target_tariff_number)

        case rtype
        when "PACD"
          indicator = process_add_cvd_line(product, target_tariff_number, line, changed)
          if indicator.present?
            cvd_add_indicators[target_tariff_number] << indicator
          end
        when "PDOT"
          process_dot_line(product, target_tariff_number, line, changed)
        when "PFDA"
          process_fda_line(product, target_tariff_number, line, changed)
        when "PFDF"
          process_fda_affirmation_of_compliance_line(product, target_tariff_number, line, changed, counter)
        when "PLAC"
          process_lacey_line(product, target_tariff_number, line, changed, counter)
        when "PFWS"
          process_fws_line(product, target_tariff_number, line, changed, counter)
        when "PSUB"
          subline = process_sub_line(product, target_tariff_number, line, changed)
          sublines << subline unless subline.nil?
        end
      end

      # Now that we've read through all the lines we can set the document types gathered into the docs field
      process_required_documents_set product, documents, changed

      remove_unreferenced_records product, tariff_row_counters, cvd_add_indicators, sublines, changed

      # If we got a new product or if anything changed we need to save the product and snapshot it
      if new_product || product_changed?(changed)
        # Only set this here so that we only update if the product actually changed.
        product.last_exported_from_source = source_system_time
        product.save!
        inbound_file.set_identifier_module_info :part_number, Product, product.id, value: product.unique_identifier
        product.create_snapshot user, nil, inbound_file.s3_path
      end
    end
  end

  def find_part_line_types lines, line_type
    lines.select { |line| row_type(line) == line_type }
  end

  # The way Target handles supplemental tariffs is really strange.  They send a single
  # line with the "primary tariff" (in the case of 9903/9902 tariffs these will be the primary),
  # and then they send a second line with primary from the previous line repeated and a secondary tariff
  # on this second line.
  #
  # What's even more of a pain is then every single subline or PGA record is sent for both lines as well.
  #
  # What we're doing here is providing a mapping of which is the "valid" tariff line and which is
  # a throwaway that doesn't have all the data.  And then later we'll only parse the valid ones.
  def create_tariff_line_remapping tariff_lines
    # TODO Need to determine what to do for Assortments - they appear to
    # have the reverse layout of the others WRT supplemental tariff numbers

    # We're going to group all the lines together that need to be squished together and then
    # process them all as a single group
    remapped_tariff_lines = Hash.new {|k, v| k[v] = [] }
    array_index = 0
    while array_index < tariff_lines.length
      line = tariff_lines[array_index]
      current_index = integer_value(line, 10)
      remapped_tariff_lines[current_index] << line

      tariff = primary_tariff(line)
      supplemental_tariff = secondary_tariff(line)

      next_array_index = array_index + 1

      # We only need to look forward to the next line if the supplemental tariff is blank..because that's
      # the only real condition where the two lines might be joined together in the standard case
      if supplemental_tariff.blank? && next_array_index < tariff_lines.length
        next_line = tariff_lines[next_array_index]
        next_tariff = primary_tariff(next_line)
        next_supplemental = secondary_tariff(next_line)

        if next_tariff == tariff && next_supplemental.present?
          # In this case, we have a following line that looks to be connected to our current line
          remapped_tariff_lines[current_index] << next_line
          next_array_index += 1
        end
      end

      # If we found additional lines that are part of this grouping, then we want to skip them
      # in our outer group, since we've already captured them.  So use the inner index
      # as the marker for which line to examine next
      array_index = next_array_index
    end

    # Dup the hash to get rid of the default array add for a key miss (.ie the block passed to the initializer)
    new_tariffs = {}
    remapped_tariff_lines.each_pair do |k, v|
      new_tariffs[k] = v
    end

    new_tariffs
  end

  def process_product_header_line product, line, changed
    set_custom_value(product, :prod_part_number, nil, row_value(line, 7))
    set_custom_value(product, :prod_vendor_order_point, nil, row_value(line, 9))
    set_value(product, :inactive, changed, (text_value(line, 10) == "H"))
    set_custom_value(product, :prod_type, changed, text_value(line, 11))
    set_custom_value(product, :prod_vendor_style, changed, text_value(line, 12))
    set_value(product, :name, changed, text_value(line, 14))
    set_custom_value(product, :prod_long_description, changed, text_value(line, 15))
    set_custom_value(product, :prod_tsca, changed, boolean_value(line, 27))
    set_custom_value(product, :prod_aphis, changed, boolean_value(line, 30))
    set_custom_value(product, :prod_usda, changed, boolean_value(line, 31))
    set_custom_value(product, :prod_epa, changed, boolean_value(line, 32))
    set_custom_value(product, :prod_cps, changed, boolean_value(line, 33))

    nil
  end

  def process_required_documents_line line
    new_document = text_value(line, 10).upcase
    new_document.blank? ? nil : new_document.strip
  end

  def process_required_documents_set product, documents, changed
    set_custom_value(product, :prod_required_documents, changed, Product.create_newline_split_field(documents.sort))
  end

  def process_classification_lines product, target_tariff_number, tariff_lines, changed
    # There's potentially multiple rows from the file here that represent a single tariff record in our system.
    # See create_tariff_line_remapping for an explanation.  We can extract all the tariff numbers from the
    # lines and then just use the first line for all the other pieces of data (since the tariff info
    # is the only thing different we care about on each line)
    tariffs = Set.new

    tariff_lines.each do |line|
      t = primary_tariff(line)
      tariffs << t if t.present?
      t = secondary_tariff(line)
      tariffs << t if t.present?
    end
    tariffs = tariffs.to_a
    line = tariff_lines.first

    tariff_record(product, target_tariff_number, line, changed) do |tariff|
      set_custom_value(tariff, :tar_country_of_origin, changed, text_value(line, 9))
      set_value(tariff, :hts_1, changed, tariffs[0])
      set_value(tariff, :hts_2, changed, tariffs[1])
      set_value(tariff, :hts_3, changed, tariffs[2])
      set_custom_value(tariff, :tar_spi_primary, changed, text_value(line, 20))
      set_custom_value(tariff, :tar_xvv, changed, text_value(line, 21))
      set_custom_value(tariff, :tar_component_description, changed, text_value(line, 22))
    end

    nil
  end

  def process_add_cvd_line product, target_tariff_number, line, changed
    indicator = nil
    tariff_record(product, target_tariff_number, line, changed) do |tariff|
      indicator = text_value(line, 10).strip.upcase
      case_number = text_value(line, 11)
      if indicator == "A"
        set_custom_value(tariff, :tar_add_case, changed, case_number)
      elsif indicator == "C"
        set_custom_value(tariff, :tar_cvd_case, changed, case_number)
      end
    end

    indicator
  end

  def process_dot_line product, target_tariff_number, line, changed
    tariff_record(product, target_tariff_number, line, changed) do |tariff|
      set_custom_value(tariff, :tar_dot_flag, changed, true)

      box_number = text_value(line, 10)
      # Target is only sending us the box number (which looks to be hardcoded to 2A if DOT data is sent)
      # Box 2A correlates to the REI program (Regulated motor vehicle equipment items that are subject
      # to the Federal motor vehicle safety standards )
      #
      # If there's other box numbers they send in the future, we'll ahve to add additional program
      # correlations.
      program = box_number.to_s.upcase == "2A" ? "REI" : nil

      set_custom_value(tariff, :tar_dot_program, changed, program)
      set_custom_value(tariff, :tar_dot_box_number, changed, box_number)
    end

    nil
  end

  def process_fda_line product, target_tariff_number, line, changed
    tariff_record(product, target_tariff_number, line, changed) do |tariff|
      set_custom_value(tariff, :tar_fda_flag, changed, true)
      set_custom_value(tariff, :tar_fda_product_code, changed, text_value(line, 10))
      set_custom_value(tariff, :tar_fda_cargo_status, changed, text_value(line, 11))
      set_custom_value(tariff, :tar_fda_food, changed, boolean_value(line, 17))
    end

    nil
  end

  def process_fda_affirmation_of_compliance_line product, target_tariff_number, line, changed, counter
    return if counter > 7

    tariff_record(product, target_tariff_number, line, changed) do |tariff|
      set_custom_value(tariff, "tar_fda_affirmation_code_#{counter}", changed, text_value(line, 10))
      set_custom_value(tariff, "tar_fda_affirmation_qualifier_#{counter}", changed, text_value(line, 11))
    end

    nil
  end

  def process_lacey_line product, target_tariff_number, line, changed, counter
    return if counter > 10

    tariff_record(product, target_tariff_number, line, changed) do |tariff|
      set_custom_value(tariff, :tar_lacey_flag, changed, true)
      set_custom_value(tariff, "tar_lacey_common_name_#{counter}", changed, text_value(line, 10))
      set_custom_value(tariff, "tar_lacey_genus_#{counter}", changed, text_value(line, 11))
      set_custom_value(tariff, "tar_lacey_species_#{counter}", changed, text_value(line, 12))
      set_custom_value(tariff, "tar_lacey_country_#{counter}", changed, text_value(line, 13))
      set_custom_value(tariff, "tar_lacey_quantity_#{counter}", changed, decimal_value(line, 14))
      set_custom_value(tariff, "tar_lacey_uom_#{counter}", changed, text_value(line, 15))
      set_custom_value(tariff, "tar_lacey_recycled_#{counter}", changed, decimal_value(line, 16))
    end

    nil
  end

  def process_fws_line product, target_tariff_number, line, changed, counter
    return if counter > 5

    tariff_record(product, target_tariff_number, line, changed) do |tariff|
      set_custom_value(tariff, :tar_fws_flag, changed, true)
      set_custom_value(tariff, "tar_fws_genus_#{counter}", changed, text_value(line, 11))
      set_custom_value(tariff, "tar_fws_country_origin_#{counter}", changed, text_value(line, 14))
      set_custom_value(tariff, "tar_fws_species_#{counter}", changed, text_value(line, 15))
      set_custom_value(tariff, "tar_fws_general_name_#{counter}", changed, text_value(line, 16))
      set_custom_value(tariff, "tar_fws_cost_#{counter}", changed, decimal_value(line, 17))
      set_custom_value(tariff, "tar_fws_description_#{counter}", changed, text_value(line, 23))
      set_custom_value(tariff, "tar_fws_description_code_#{counter}", changed, text_value(line, 24))
      set_custom_value(tariff, "tar_fws_source_code_#{counter}", changed, text_value(line, 25))
    end
  end

  def process_sub_line product, target_tariff_number, line, changed
    # A subline is really only utilized for "Assortment" product types (.ie sets).
    # They're basically like a sub-product.
    # So like for a package that has a pillow and a blanket, the whole thing will
    # have a unique assortment number and then each component (pillow / blanket) will
    # have a subline.
    #
    # While these aren't exactly what we created the variant data structure for (which was
    # more like for different style numbers associated with the same part) the structure
    # still mostly works here.
    subline_identifier = text_value(line, 10)
    return if subline_identifier.blank?

    subline = product.variants.find {|v| v.variant_identifier == subline_identifier}
    if subline.nil?
      subline = product.variants.build variant_identifier: subline_identifier
      changed.value = true
    end

    set_custom_value(subline, :var_quantity, changed, decimal_value(line, 11))
    set_custom_value(subline, :var_hts_line, changed, target_tariff_number)
    set_custom_value(subline, :var_lacey_species, changed, text_value(line, 12))
    set_custom_value(subline, :var_lacey_country_harvest, changed, text_value(line, 13))

    subline
  end

  def remove_unreferenced_records product, tariff_row_counters, cvd_add_indicators, sublines_utilized, changed
    # Remove any tariff lines that were not part of the present file.
    remove_unreferenced_tariff_rows(product, tariff_row_counters, changed)
    remove_unreferenced_fda_fields(product, tariff_row_counters, changed)
    remove_unreferenced_affirmation_fields(product, tariff_row_counters, changed)
    remove_unreferenced_dot_fields(product, tariff_row_counters, changed)
    remove_unreferenced_lacey_fields(product, tariff_row_counters, changed)
    remove_unreferenced_fws_fields(product, tariff_row_counters, changed)
    remove_unreferenced_sublines(product, sublines_utilized, changed)
    remove_unreferenced_add_cvd_fields(product, tariff_row_counters, cvd_add_indicators, changed)
    nil
  end

  def remove_unreferenced_tariff_rows product, tariff_row_counters, changed
    classification_counter_values(product, tariff_row_counters, "PCLN") do |classification, tariff_line_counts|
      classification.tariff_records.each do |tariff|
        if !tariff_line_counts.include?(tariff_line_number(tariff))
          tariff.destroy!
          changed.value = true
        end
      end
    end

    nil
  end

  def remove_unreferenced_fda_fields product, tariff_row_counters, changed
    # Basically, if a tariff row didn't get an FDA record and currently has the fields referenced by that row, then those fields should be nil'ed out
    tariff_counter_value(product, tariff_row_counters, "PFDA") do |_classification, tariff, record_count|
      if record_count == 0
        remove_custom_value(tariff, :tar_fda_flag, changed)
        remove_custom_value(tariff, :tar_fda_product_code, changed)
        remove_custom_value(tariff, :tar_fda_cargo_status, changed)
        remove_custom_value(tariff, :tar_fda_food, changed)
      end
    end
  end

  def remove_unreferenced_affirmation_fields product, tariff_row_counters, changed
    # Remove any affirmation of compliance fields not referenced (there's only 7 max allowed)
    tariff_counter_value(product, tariff_row_counters, "PFDF") do |_classification, tariff, record_count|
      if record_count <= 7
        counter = 7
        begin
          remove_custom_value(tariff, "tar_fda_affirmation_code_#{counter}", changed)
          remove_custom_value(tariff, "tar_fda_affirmation_qualifier_#{counter}", changed)
        end while (counter -= 1) < record_count
      end
    end
  end

  def remove_unreferenced_dot_fields product, tariff_row_counters, changed
    tariff_counter_value(product, tariff_row_counters, "PDOT") do |_classification, tariff, record_count|
      if record_count == 0
        remove_custom_value(tariff, :tar_dot_flag, changed)
        remove_custom_value(tariff, :tar_dot_program, changed)
        remove_custom_value(tariff, :tar_dot_box_number, changed)
      end
    end
  end

  def remove_unreferenced_lacey_fields product, tariff_row_counters, changed
    # Remove any lacey fields not referenced (there's only 7 max allowed)
    tariff_counter_value(product, tariff_row_counters, "PLAC") do |_classification, tariff, record_count|
      remove_custom_value(tariff, :tar_lacey_flag, changed) if record_count == 0

      if record_count <= 10
        counter = 10
        begin
          remove_custom_value(tariff, "tar_lacey_common_name_#{counter}", changed)
          remove_custom_value(tariff, "tar_lacey_genus_#{counter}", changed)
          remove_custom_value(tariff, "tar_lacey_species_#{counter}", changed)
          remove_custom_value(tariff, "tar_lacey_country_#{counter}", changed)
          remove_custom_value(tariff, "tar_lacey_quantity_#{counter}", changed)
          remove_custom_value(tariff, "tar_lacey_uom_#{counter}", changed)
          remove_custom_value(tariff, "tar_lacey_recycled_#{counter}", changed)
        end while (counter -= 1) > record_count
      end
    end
  end

  def remove_unreferenced_fws_fields product, tariff_row_counters, changed
    # Remove any Fish and Wildlife fields not referenced (there's only 7 max allowed)
    tariff_counter_value(product, tariff_row_counters, "PFWS") do |_classification, tariff, record_count|
      remove_custom_value(tariff, :tar_fws_flag, changed) if record_count == 0

      if record_count <= 5
        counter = 5
        begin
          remove_custom_value(tariff, "tar_fws_genus_#{counter}", changed)
          remove_custom_value(tariff, "tar_fws_species_#{counter}", changed)
          remove_custom_value(tariff, "tar_fws_general_name_#{counter}", changed)
          remove_custom_value(tariff, "tar_fws_country_origin_#{counter}", changed)
          remove_custom_value(tariff, "tar_fws_cost_#{counter}", changed)
          remove_custom_value(tariff, "tar_fws_description_#{counter}", changed)
          remove_custom_value(tariff, "tar_fws_description_code_#{counter}", changed)
          remove_custom_value(tariff, "tar_fws_source_code_#{counter}", changed)
        end while (counter -= 1) > record_count
      end
    end
  end

  def remove_unreferenced_add_cvd_fields product, tariff_row_counters, add_cvd_indicator, changed
    tariff_counter_value(product, tariff_row_counters, "PACD") do |_classification, tariff, record_count|
      if record_count < 2
        indicators = add_cvd_indicator[tariff_line_number(tariff)]
        if !indicators.include?("A")
          remove_custom_value(tariff, :tar_add_case, changed)
        end

        if !indicators.include?("C")
          remove_custom_value(tariff, :tar_cvd_case, changed)
        end
      end
    end
  end

  def remove_unreferenced_sublines product, sublines, changed
    referenced_components = Set.new(sublines.map(&:variant_identifier))

    product.variants.each do |v|
      if !referenced_components.include?(v.variant_identifier)
        v.mark_for_destruction
        changed.value = true
      end
    end

    nil
  end

  def product_changed? changed
    changed.value
  end

  private

    def text_value row, index, ensure_string: true
      v = row_value(row, index)
      v = v.to_s if ensure_string

      v
    end

    def boolean_value row, index
      v = row_value(row, index)
      v.to_s.strip.upcase == "Y"
    end

    def integer_value row, index
      v = text_value(row, index).strip
      BigDecimal(v).to_i
    end

    def decimal_value row, index
      v = text_value(row, index).strip
      return nil if v.blank?

      BigDecimal(v)
    end

    def tariff_row_number row, tariff_row_index: nil
      tariff_row_index = 9 if tariff_row_index.nil?

      tariff_row = integer_value(row, tariff_row_index)
      tariff_row.nonzero? ? tariff_row : nil
    end

    def set_tariff_counter_value line, counters, target_tariff_number
      country = text_value(line, 2)
      counters[country][row_type(line)][target_tariff_number] += 1
    end

    def classification_counter_values product, counters, row_type
      counters.each_pair do |country_iso, records|
        country = find_country(country_iso)
        # What we need to do is destroy any line number appearing AFTER the line counter for the given country
        classification = product.classifications.find {|c| c.country_id == country.id }
        yield classification, records[row_type]
      end
    end

    def tariff_counter_value product, counters, row_type
      classification_counter_values(product, counters, row_type) do |classification, tariff_line_counts|
        classification.tariff_records.each do |tariff_record|
          yield classification, tariff_record, tariff_line_counts[tariff_line_number(tariff_record)]
        end
      end
    end

    def tariff_record product, target_tariff_number, line, changed
      iso_code = text_value(line, 2)
      classification_country = find_country(iso_code)
      raise "Unable to find Country information for '#{iso_code}'." if classification_country.nil?

      classification = product.classifications.find {|c| c.country_id == classification_country.id }
      if classification.nil?
        classification = product.classifications.build country: classification_country
        changed.value = true
      end

      tariff = classification.tariff_records.find {|t| tariff_line_number(t) == target_tariff_number }
      if tariff.nil?
        tariff = classification.tariff_records.build
        set_custom_value(tariff, :tar_external_line_number, changed, target_tariff_number)
      end

      yield tariff

      tariff
    end

    def existing_documents_set existing_documents
      Set.new(Product.split_newline_values(existing_documents.to_s.upcase))
    end

    def cdefs
      @cdefs ||= self.class.prep_custom_definitions([:prod_part_number, :prod_vendor_order_point, :prod_type,
        :prod_vendor_style, :prod_long_description, :prod_aphis, :prod_usda, :prod_epa, :prod_cps, :prod_tsca,
        :prod_required_documents, :tar_external_line_number, :tar_country_of_origin, :tar_spi_primary, :tar_xvv, :tar_component_description,
        :tar_cvd_case, :tar_add_case, :tar_dot_flag, :tar_dot_program, :tar_dot_box_number, :tar_fda_flag, :tar_fda_product_code,
        :tar_fda_cargo_status, :tar_fda_food, :tar_fda_affirmation_code_1, :tar_fda_affirmation_code_2, :tar_fda_affirmation_code_3,
        :tar_fda_affirmation_code_4, :tar_fda_affirmation_code_5, :tar_fda_affirmation_code_6, :tar_fda_affirmation_code_7,
        :tar_fda_affirmation_qualifier_1, :tar_fda_affirmation_qualifier_2, :tar_fda_affirmation_qualifier_3, :tar_fda_affirmation_qualifier_4,
        :tar_fda_affirmation_qualifier_5, :tar_fda_affirmation_qualifier_6, :tar_fda_affirmation_qualifier_7, :tar_lacey_flag, :tar_lacey_common_name_1,
        :tar_lacey_common_name_2, :tar_lacey_common_name_3, :tar_lacey_common_name_4, :tar_lacey_common_name_5, :tar_lacey_common_name_6,
        :tar_lacey_common_name_7, :tar_lacey_common_name_8, :tar_lacey_common_name_9, :tar_lacey_common_name_10, :tar_lacey_genus_1,
        :tar_lacey_genus_2, :tar_lacey_genus_3, :tar_lacey_genus_4, :tar_lacey_genus_5, :tar_lacey_genus_6, :tar_lacey_genus_7,
        :tar_lacey_genus_8, :tar_lacey_genus_9, :tar_lacey_genus_10, :tar_lacey_species_1, :tar_lacey_species_2, :tar_lacey_species_3,
        :tar_lacey_species_4, :tar_lacey_species_5, :tar_lacey_species_6, :tar_lacey_species_7, :tar_lacey_species_8, :tar_lacey_species_9,
        :tar_lacey_species_10, :tar_lacey_country_1, :tar_lacey_country_2, :tar_lacey_country_3, :tar_lacey_country_4, :tar_lacey_country_5,
        :tar_lacey_country_6, :tar_lacey_country_7, :tar_lacey_country_8, :tar_lacey_country_9, :tar_lacey_country_10, :tar_lacey_quantity_1,
        :tar_lacey_quantity_2, :tar_lacey_quantity_3, :tar_lacey_quantity_4, :tar_lacey_quantity_5, :tar_lacey_quantity_6, :tar_lacey_quantity_7,
        :tar_lacey_quantity_8, :tar_lacey_quantity_9, :tar_lacey_quantity_10, :tar_lacey_uom_1, :tar_lacey_uom_2, :tar_lacey_uom_3, :tar_lacey_uom_4,
        :tar_lacey_uom_5, :tar_lacey_uom_6, :tar_lacey_uom_7, :tar_lacey_uom_8, :tar_lacey_uom_9, :tar_lacey_uom_10, :tar_lacey_recycled_1, :tar_lacey_recycled_2,
        :tar_lacey_recycled_3, :tar_lacey_recycled_4, :tar_lacey_recycled_5, :tar_lacey_recycled_6, :tar_lacey_recycled_7, :tar_lacey_recycled_8,
        :tar_lacey_recycled_9, :tar_lacey_recycled_10, :tar_fws_flag, :tar_fws_genus_1, :tar_fws_genus_2, :tar_fws_genus_3, :tar_fws_genus_4, :tar_fws_genus_5,
        :tar_fws_species_1, :tar_fws_species_2, :tar_fws_species_3, :tar_fws_species_4, :tar_fws_species_5, :tar_fws_general_name_1, :tar_fws_general_name_2,
        :tar_fws_general_name_3, :tar_fws_general_name_4, :tar_fws_general_name_5, :tar_fws_country_origin_1, :tar_fws_country_origin_2,
        :tar_fws_country_origin_3, :tar_fws_country_origin_4, :tar_fws_country_origin_5, :tar_fws_cost_1, :tar_fws_cost_2, :tar_fws_cost_3,
        :tar_fws_cost_4, :tar_fws_cost_5, :tar_fws_description_1, :tar_fws_description_2, :tar_fws_description_3, :tar_fws_description_4, :tar_fws_description_5,
        :tar_fws_description_code_1, :tar_fws_description_code_2, :tar_fws_description_code_3, :tar_fws_description_code_4, :tar_fws_description_code_5,
        :tar_fws_source_code_1, :tar_fws_source_code_2, :tar_fws_source_code_3, :tar_fws_source_code_4, :tar_fws_source_code_5,
        :var_quantity, :var_hts_line, :var_lacey_species, :var_lacey_country_harvest
      ])
    end

    def find_or_create_product product_header, system_extract_time
      # The combination of Part Number and Order Point is what will uniquely define
      # a specific part.  The part number itself is not unique enough as you can have
      # distinct different tariff data based on the vendor's origin (which is what the
      # order point is - a unique identifier for the "factory")
      dpci_part_number = row_value(product_header, 7)
      vendor_order_point = row_value(product_header, 9)
      return nil if dpci_part_number.blank? || vendor_order_point.blank?

      unique_identifier = build_part_number(dpci_part_number, vendor_order_point)
      inbound_file.add_identifier :part_number, unique_identifier

      product = nil
      created = false
      Lock.acquire("Product-#{unique_identifier}") do
        product = Product.where(importer: importer, unique_identifier: unique_identifier).first_or_initialize
        if !product.persisted?
          product.save!
          created = true
        end
      end

      return if product.nil?

      Lock.db_lock(product) do
        return nil unless process_product?(product, system_extract_time)
        yield product, created
      end

      product
    end

    def process_product? product, system_extract_date
      product.last_exported_from_source.nil? || product.last_exported_from_source <= system_extract_date
    end

    def importer
      @importer ||= begin
        c = Company.with_customs_management_number("TARGEN").first
        raise "No importer account exists with 'TARGEN' account number." if c.nil?
        c
      end

      @importer
    end

    def row_type row
      row_value(row, 1).to_s
    end

    def split_part_data_into_parts part_data
      part_rows = []
      current_part_rows = nil
      part_data.each do |row|
        type = row_type(row)
        next if type == "PCTL"

        if type == "PHDR"
          part_rows << current_part_rows if data?(current_part_rows)
          current_part_rows = []
        end

        current_part_rows << row unless current_part_rows.nil?
      end

      part_rows << current_part_rows if data?(current_part_rows)
      part_rows
    end

    def data? rows
      rows && rows.length > 0
    end

    def find_row_type row_type, rows
      rows.find {|r| row_type(r) == row_type }
    end

    def source_timestamp pctl_row
      # When concatted these to fields make a timestamp like YYYYmmddHHMMSS (which ActiveSupport::TimeZone can parse directly)
      timestamp = row_value(pctl_row, 7).to_s + row_value(pctl_row, 8).to_s

      # The value of YYYYmmddHHMMSS
      timestamp.blank? ? nil : time_zone.parse(timestamp)
    end

    def time_zone
      Time.zone
    end

    def find_country iso_code
      @countries ||= Hash.new do |h, k|
        h[k] = Country.where(iso_code: k).first
      end

      @countries[iso_code]
    end

    def primary_tariff line
      text_value(line, 11)
    end

    def secondary_tariff line
      text_value(line, 15)
    end

    def tariff_line_number tariff
      tariff.custom_value(cdefs[:tar_external_line_number]).to_i
    end

end; end; end; end
