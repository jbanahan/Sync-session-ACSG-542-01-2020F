require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/mutable_boolean'
require 'open_chain/custom_handler/amazon/amazon_product_parser_support'

module OpenChain; module CustomHandler; module Amazon; class AmazonFdaProductParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::Amazon::AmazonProductParserSupport

  def self.parse data, opts = {}
    csv_data = CSV.parse(data)
    self.new(file_type(opts[:key])).process_parts(csv_data, User.integration, opts[:key])
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_fda_product, :prod_fda_product_code, :prod_fda_brand_name, :prod_fda_affirmation_compliance, :prod_fda_affirmation_compliance_value]
  end

  def initialize file_type
    @fda_file_type = file_type
  end

  def process_part_lines(user, filename, lines)
    # FDA files will only have a single line for specific parts
    line = Array.wrap(lines).first

    find_or_create_product(line) do |product|
      changed = MutableBoolean.new false
      if @fda_file_type == :fdg
        process_fdg_file(product, changed, line)
      elsif @fda_file_type == :fct
        process_fct_file(product, changed, line)
      end

      if changed.value
        product.save!
        product.create_snapshot user, nil, filename
      end
    end
  end

  def process_fdg_file(product, changed, line)
    standard_parsing(product, changed, line)
  end

  def process_fct_file(product, changed, line)
    standard_parsing(product, changed, line)
    chinese_ceramic_factory_code_number = text(line[17])
    if chinese_ceramic_factory_code_number.blank?
      set_custom_value(product, :prod_fda_affirmation_compliance, changed, nil)
      set_custom_value(product, :prod_fda_affirmation_compliance_value, changed, chinese_ceramic_factory_code_number)
    else
      # See the FDA's Affirmation of Compliance Codes (currently: https://www.fda.gov/industry/entry-submission-process/affirmation-compliance-codes)
      # for all the codes.  This feed seems to just be about the Chinese Ceramic code.
      set_custom_value(product, :prod_fda_affirmation_compliance, changed, "CCC")
      set_custom_value(product, :prod_fda_affirmation_compliance_value, changed, chinese_ceramic_factory_code_number)  
    end
  end

  def standard_parsing product, changed, line
    set_custom_value(product, :prod_fda_product, changed, true)
    set_custom_value(product, :prod_fda_brand_name, changed, text(line[13]))
    set_custom_value(product, :prod_fda_product_code, changed, text(line[16]))
  end

  def self.file_type filename
    filename = File.basename(filename)
    
    if filename.to_s =~ /^US_PGA_([^_]+)_.+\.csv$/i
      if $1.to_s.upcase == "FDG"
        return :fdg
      elsif $1.to_s.upcase == "FCT"
        return :fct
      else
        inbound_file.reject_and_raise("Unexpected file type of '#{$1}' found by FDA Parser.")
      end
    else
      inbound_file.reject_and_raise("Unexpected file type found by FDA Parser.")
    end
  end

end; end; end; end