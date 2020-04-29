require 'fuzzy_match'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/mutable_boolean'
require 'open_chain/custom_handler/amazon/amazon_product_parser_support'

module OpenChain; module CustomHandler; module Amazon; class AmazonCvdAddProductParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::Amazon::AmazonProductParserSupport

  def self.parse data, opts = {}
    csv_data = CSV.parse(data)
    self.new(file_type(opts[:key])).process_parts(csv_data, User.integration, opts[:key])
  end

  def initialize file_type
    @file_type = file_type
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_add_case, :prod_add_disclaimed, :prod_cvd_case, :prod_cvd_disclaimed]
  end

  def process_part_lines(user, filename, lines)
    line = Array.wrap(lines).first

    find_or_create_product(line) do |product|
      changed = MutableBoolean.new false

      standard_parsing @file_type, product, changed, line

      if changed.value
        product.save!
        product.create_snapshot user, nil, filename
      end
    end
  end

  def standard_parsing file_type, product, changed, line
    case_number = line[12]

    if file_type == :add
      disclaimed = parse_boolean(line[17])
      set_custom_value(product, :prod_add_case, changed, case_number)
      set_custom_value(product, :prod_add_disclaimed, changed, disclaimed)
    elsif file_type == :cvd
      disclaimed = parse_boolean(line[15])
      set_custom_value(product, :prod_cvd_case, changed, case_number)
      set_custom_value(product, :prod_cvd_disclaimed, changed, disclaimed)
    end

    nil
  end

  def self.file_type filename
    filename = File.basename(filename)

    if filename.to_s =~ /^US_PGA_([^_]+)_.+\.csv$/i
      if $1.to_s.upcase == "ADD"
        return :add
      elsif $1.to_s.upcase == "CVD"
        return :cvd
      else
        inbound_file.reject_and_raise("Unexpected file type of '#{$1}' found by ADD/CVD Parser.")
      end
    else
      inbound_file.reject_and_raise("Unexpected file type found by ADD/CVD Parser.")
    end
  end


end; end; end; end