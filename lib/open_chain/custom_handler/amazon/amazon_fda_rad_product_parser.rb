require 'fuzzy_match'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/mutable_boolean'
require 'open_chain/custom_handler/amazon/amazon_product_parser_support'

module OpenChain; module CustomHandler; module Amazon; class AmazonFdaRadProductParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::Amazon::AmazonProductParserSupport

  def self.parse data, opts = {}
    csv_data = CSV.parse(data)
    self.new.process_parts(csv_data, User.integration, opts[:key])
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_fda_model_number, :prod_fda_brand_name, :prod_fda_contact_name, :prod_fda_contact_title,
                                                    :prod_fda_product_code, :prod_fda_container_type, :prod_fda_items_per_inner_container, :prod_fda_affirmation_compliance,
                                                    :prod_fda_affirmation_compliance_value, :prod_fda_manufacture_date, :prod_fda_exclusion_reason, :prod_fda_unknown_reason,
                                                    :prod_fda_accession_number, :prod_fda_manufacturer_name, :prod_fda_warning_accepted]
  end

  def process_part_lines(user, filename, lines)
    # FDA files will only have a single line for specific parts
    line = Array.wrap(lines).first

    find_or_create_product(line) do |product|
      changed = MutableBoolean.new false

      standard_parsing product, changed, line

      if changed.value
        product.save!
        product.create_snapshot user, nil, filename
      end
    end
  end

  def standard_parsing product, changed, line
    set_custom_value(product, :prod_fda_model_number, changed, line[11])
    set_custom_value(product, :prod_fda_brand_name, changed, line[12])
    set_custom_value(product, :prod_fda_contact_name, changed, line[13])
    set_custom_value(product, :prod_fda_contact_title, changed, line[14])
    set_custom_value(product, :prod_fda_product_code, changed, line[15])
    set_custom_value(product, :prod_fda_container_type, changed, line[17])
    set_custom_value(product, :prod_fda_items_per_inner_container, changed, line[18])

    # The values used in the RAD Declaration's affirmation of compliance values differ based
    # on the type of declaration it is.  The qualifiers that can be used are the Manufacture Date,
    # or Exlusion Reason or Manufacturer Name
    set_custom_value(product, :prod_fda_manufacture_date, changed, parse_date(line[20], date_format: "%m/%d/%y"))
    set_custom_value(product, :prod_fda_exclusion_reason, changed, line[21])
    set_custom_value(product, :prod_fda_unknown_reason, changed, line[22])
    set_custom_value(product, :prod_fda_accession_number, changed, line[23])
    set_custom_value(product, :prod_fda_manufacturer_name, changed, line[25])
    set_custom_value(product, :prod_fda_warning_accepted, changed, parse_boolean(line[26]))

    affirmation_compliance_code, affirmation_compliance_qualifier = rad_declaration(product, line[19])
    set_custom_value(product, :prod_fda_affirmation_compliance, changed, affirmation_compliance_code)
    set_custom_value(product, :prod_fda_affirmation_compliance_value, changed, affirmation_compliance_qualifier)
  end

  def rad_declaration product, declaration_value
    declaration = [nil, nil]
    return declaration if declaration_value.blank?

    @xref ||= begin
      @xref = DataCrossReference.hash_for_type(DataCrossReference::ACE_RADIATION_DECLARATION)
      # We're going to use the fuzzy match to determine the "best" key match from the file, just in case
      # there's some differences in the wording from the declarations we've set up in the cross reference
      @fuzzy_match = FuzzyMatch.new(@xref.keys)

      @xref
    end

    # There's a couple declarations that are over 256 chars...which overflows the field, so just trim these
    matching_key = @fuzzy_match.find declaration_value[0..255]
    declaration_code = nil
    if matching_key
      declaration_code = @xref[matching_key]
    end

    if declaration_code
      declaration[0] = declaration_code
      declaration[1] = affirmation_of_compliance_qualifier(product, declaration_code)
    end

    declaration
  end

  def affirmation_of_compliance_qualifier product, compliance_code
    # This data comes from the "FDA Affirmations of Compliance for the Automated Commercial Environment" ACE documentation
    # Currently found here: https://www.fda.gov/media/96145/download

    # "RA1" -> Date of Manufacture
    # "RA2" -> FDA Exclusion Reason
    # "RA3" -> (no qualifier)
    # "RA4" -> (no qualifier)
    # "RA5" -> The qualifier required is the textual description of the end product. (don't have this value)
    # "RA6" -> (no qualifier)
    # "RA7" -> The qualifier required is the textual description of the end product. (don't have this value)
    # 'RB1' -> (no qualifier)
    # 'RB2' -> FDA Unknown Reason
    # 'RC1' -> (no qualifier)
    # 'RC2' -> The qualifier must list the dates of trade shows (don't have this - appaers to be a 1-off anyway)
    # 'RD1' -> (no qualifier)
    # 'RD2' -> (no qualifier)
    # 'RD3' -> (don't have this)
    case compliance_code
    when "RA1"
      # According to the ACE documentation, the example given for how this date should be given is like "Feb 2, 2019"
      value = product.custom_value(cdefs[:prod_fda_manufacture_date])
      return value.present? ? value.strftime("%b %d, %Y") : nil
    when "RA2"
      return product.custom_value(cdefs[:prod_fda_exclusion_reason])
    when "RB2"
      return product.custom_value(cdefs[:prod_fda_unknown_reason])
    else
      return nil
    end
  end

end; end; end; end