require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/mutable_boolean'
require 'open_chain/custom_handler/amazon/amazon_product_parser_support'

module OpenChain; module CustomHandler; module Amazon; class AmazonLaceyProductParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::Amazon::AmazonProductParserSupport

  def self.parse data, opts = {}
    csv_data = CSV.parse(data)
    self.new.process_parts(csv_data, User.integration, opts[:key])
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_lacey_component_of_article, :prod_lacey_genus_1, :prod_lacey_species_1, :prod_lacey_genus_2, :prod_lacey_species_2,
                                                    :prod_lacey_country_of_harvest, :prod_lacey_quantity, :prod_lacey_quantity_uom, :prod_lacey_percent_recycled, :prod_lacey_preparer_name,
                                                    :prod_lacey_preparer_phone, :prod_lacey_preparer_email]
  end

  def process_part_lines(user, filename, lines)
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
    set_custom_value(product, :prod_lacey_component_of_article, changed, line[11])
    set_custom_value(product, :prod_lacey_genus_1, changed, line[12])
    set_custom_value(product, :prod_lacey_species_1, changed, line[14])
    set_custom_value(product, :prod_lacey_country_of_harvest, changed, line[15])
    set_custom_value(product, :prod_lacey_quantity, changed, parse_decimal(line[16]))
    set_custom_value(product, :prod_lacey_quantity_uom, changed, line[17])
    set_custom_value(product, :prod_lacey_percent_recycled, changed, parse_decimal(line[18]))
    set_custom_value(product, :prod_lacey_preparer_name, changed, line[19])
    set_custom_value(product, :prod_lacey_preparer_email, changed, line[20])
    set_custom_value(product, :prod_lacey_preparer_phone, changed, line[21])
  end

end; end; end; end