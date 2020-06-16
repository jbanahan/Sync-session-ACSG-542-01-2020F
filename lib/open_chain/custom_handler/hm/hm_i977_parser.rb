require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/change_tracking_parser_support'
require 'open_chain/custom_handler/hm/hm_business_logic_support'

# HM (for some reason) names all their feeds with random numeric values.
# This is a simple parts feed (w/ some PO data in it)
module OpenChain; module CustomHandler; module Hm; class HmI977Parser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::Hm::HmBusinessLogicSupport
  include OpenChain::CustomHandler::ChangeTrackingParserSupport

  def self.parse_file file_content, log, opts = {}
    # Each file is supposed to represent a single PO's worth of articles, so we should be ok just parsing them all
    # in a single parse attempt and not breaking them up into smaller distinct delayed job units (like we might do
    # with an EDI file)
    user = User.integration
    parser = self.new
    REXML::XPath.each(REXML::Document.new(file_content), "/ns0:CustomsMasterDataTransaction/Payload/CustomsMasterData/Articles/Article") do |xml|
      parser.process_article(xml, user, opts[:key])
    end
  end

  def process_article article_xml, user, filename
    part_number = extract_part_number(article_xml)
    find_or_create_product(part_number) do |product|
      p = nil
      if update_product_values(article_xml, product)
        product.save!
        inbound_file.add_identifier :article_number, product.custom_value(cdefs[:prod_part_number]), object: product
        product.create_snapshot user, nil, filename
        p = product
      end
      p
    end
  end

  def update_product_values article_xml, product
    # Because we're not storing every single style variant for H&M, Only set the name if it's blank
    # in the product.  The description we get from them is actually the
    # full variant one, which may include color and/or sizing info.  So, that would mean that we'd
    # end up potentially changing the name with virtually every article received.
    changed = MutableBoolean.new false
    product.name = article_xml.text("ArticleDescription") if product.name.blank?
    set_custom_value(product, :prod_product_group, changed, article_xml.text("CustId"))
    set_custom_value(product, :prod_type, changed, article_xml.text("CustType"))
    set_custom_value(product, :prod_fabric_content, changed, article_xml.text("ArticleCompositionDetails"))

    # From what I can tell, Commcode is just an abbreviated version of Importcode.  So only use it if
    # ImportCode is blank
    suggested_tariff = article_xml.text("Importcode")
    suggested_tariff = article_xml.text("Commcode") if suggested_tariff.blank?
    set_custom_value(product, :prod_suggested_tariff, changed, suggested_tariff)

    REXML::XPath.each(article_xml, "HMOrders/HMOrder") do |order|
      concat_custom_value(product, cdefs[:prod_po_numbers], order.text("HMOrderNr"), changed)
      concat_custom_value(product, cdefs[:prod_season], order.text("Season"), changed)
    end

    product.changed? || changed.value
  end

  def find_or_create_product part_number
    uid = "HENNE-#{part_number}"
    product = nil
    Lock.acquire("Product-#{uid}") do
      product = Product.where(unique_identifier: uid, importer_id: hm.id).first_or_initialize
      if !product.persisted?
        product.find_and_set_custom_value cdefs[:prod_part_number], part_number
        product.save!
      end
    end

    return nil if product.nil?

    Lock.db_lock(product) do
      product = yield product
    end

    product
  end

  def extract_part_number xml
    extract_style_number_from_sku xml.text("ArticleName")
  end

  def hm
    @cust ||= Company.where(system_code: 'HENNE').first
    raise "Failed to find customer account for 'HENNE'." if @cust.nil?

    @cust
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_po_numbers, :prod_part_number, :prod_season, :prod_product_group, :prod_type, :prod_suggested_tariff, :prod_fabric_content]
  end

  def concat_custom_value product, cdef, value, changed
    return false if value.blank?

    old_val = product.custom_value cdef
    old_vals = Set.new(Product.split_newline_values old_val)
    if !old_vals.include? value
      old_vals << value
      product.find_and_set_custom_value cdef, old_vals.to_a.join("\n ")
      changed.value = true
      return true
    else
      return false
    end
  end

  def set_earliest_custom_date product, cdef, value, changed
    return false if value.blank?

    old_val = product.custom_value cdef
    if old_val.nil? || old_val > value
      product.find_and_set_custom_value cdef, value
      changed.value = true
      return true
    else
      return false
    end
  end

end; end; end; end