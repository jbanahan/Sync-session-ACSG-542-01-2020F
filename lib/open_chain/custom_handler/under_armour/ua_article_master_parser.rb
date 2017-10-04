require 'rexml/document'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/integration_client_parser'
require 'open_chain/mutable_boolean'

module OpenChain; module CustomHandler; module UnderArmour; class UaArticleMasterParser
  extend OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ua_article_master"
  end

  def self.parse data, opts={}
    doc = REXML::Document.new data
    process_articles! doc, opts[:key]
  end

  def send_error_email error_log, file_key
    error_body = "<p>The following errors were encountered when processing file '#{File.basename(file_key.to_s)}': <br></p>"
    if error_log.missing_products.length > 0
      error_body << "<p>The following Prepack Component Products could not be found:<br><ul>"
      error_log.missing_products.each do |error|
        error_body << ("<li>Prepack Article # '#{error.article}' references missing Product '#{error.product}'.</li>")
      end
      error_body << "</ul></p>"
    end

    if error_log.missing_variants.length > 0
      error_body << "<p>The following Prepack Component Skus could not be found (Product / Variant):<br><ul>"
      error_log.missing_variants.each do |error|
        error_body << ("<li>Prepack Article # '#{error.article}' references a missing SKU # '#{error.variant}' from Product '#{error.product}'.</li>")
      end
      error_body << "</ul></p>"
    end

    if error_log.malformed_products.length > 0
      error_body << "<p>These product codes did not fit the expected format:<br><ul>"
      error_log.malformed_products.each do |malformed_product|
        error_body << ("<li>#{malformed_product}</li>")
      end
      error_body << "</ul></p>"
    end

    OpenMailer.send_simple_html(Group.use_system_group("UA Article Master Errors", name: "UA Article Master Errors"), 'UA Article Master Processing Errors', error_body.html_safe).deliver!
  end

  def self.process_articles! doc, file_key
    doc.elements.each("//Style") do |style|
      if MasterSetup.get.custom_feature?("UA Background Article Processing")
        self.delay(queue: "ua").process_article(serialize_xml(style), file_key)
      else
        process_article(style, file_key)
      end
    end
  end

  def self.process_article style, file_key
    parser = self.new

    style = deserialze_xml(style)

    error_log = PrepackErrorLog.new
    style.elements.each("Article") do |art|
      changed = MutableBoolean.new(false)
      customs_description = REXML::XPath.first(art, "ArticleAttr[Code[@Type='CommImpCode']]/Description").try :text
      p = parser.create_or_update_product! art, changed
      next if p.blank?
      
      Lock.with_lock_retry(p) do
        parser.create_or_update_variants! p, art, changed, error_log
        var_hts_codes = parser.pluck_unique_hts_values(p)
        parser.create_or_update_classi! p, customs_description, var_hts_codes, changed
        p.create_snapshot parser.user, nil, file_key if changed.value
      end
    end

    parser.send_error_email(error_log, file_key) if error_log.has_errors?
  end

  def self.deserialze_xml xml
    if xml.is_a?(String)
      REXML::Document.new(xml).root
    else
      xml
    end
  end

  def self.serialize_xml xml
    # I think there is a bug in REXML where the default formatter appears to preserve
    # the whitespace text nodes that were present in the original XML (it shouldn't)
    # ...the only way to eliminate all that whitespace is to use a pretty formatter and chop
    # it all out (which still leaves the newlines between elements).  So we'll gsub
    # those out too.  We want the XML to be as tight as possible since this is going
    # into a database table for processing.

    output = StringIO.new 
    f = REXML::Formatters::Pretty.new 0
    f.compact = true
    # don't ever wrap text to newlines inside elements
    f.width = 1_000_000

    f.write xml, output
    output.rewind
    output.read.gsub!(">\n<", "><")
  end

  def create_or_update_product! art_elem, changed
    p = nil
    puid = art_elem.text("ArticleNumber")
    return nil if puid.blank?

    pname = art_elem.text("ArticleDescription")
    product_uid = "#{system_code}-#{puid}"
    Lock.acquire("Product-#{puid}") do
      p = Product.where(unique_identifier: product_uid, importer_id: importer).first_or_initialize(unique_identifier: product_uid, importer: importer)
      p.find_and_set_custom_value(cdefs[:prod_part_number], puid) unless p.persisted?

      changed.value = true unless p.persisted?
      unless p.name == pname
        p.name = pname
        p.save!
        changed.value = true
      end
    end
    p
  end

  def create_or_update_variants! prod, art_elem, changed, error_log
    if is_prepack? art_elem
      create_or_update_prepacks! prod, art_elem, changed, error_log
    else
      art_elem.elements.each("UPC") do |upc_elem|
        var_sku = upc_elem.text("SKU")
        if var_sku.presence
          fields = extract_var_opt_fields upc_elem
          create_or_update_one_variant! var_sku, prod, fields, changed, nil
        end
      end
    end
  end

  def create_or_update_one_variant! variant_identifier, prod, fields, changed, component_qty
    v = prod.variants.where(variant_identifier: variant_identifier).first_or_initialize(variant_identifier: variant_identifier)
    changed.value = true unless v.persisted?
    fields[:var_units_per_inner_pack] = component_qty
    set_var_custom_values! v, fields, changed
  end

  def is_prepack? art_elem
    article_type = REXML::XPath.first(art_elem, "ArticleAttr[Code[@Type='ArticleType']]/Code").try :text
    article_type == 'ZPPK'
  end

  # Returns hash of BOMComponent elements keyed to their prepack product number, which is a substring of the ComponentSKU (a BOMComponent child).
  def create_bom_component_sku_hash art_elem, error_log
    bom_sku_hash = {}
    REXML::XPath.match(art_elem, "UPC/BOMComponent").each do |bom_component_elem|
      component_sku = bom_component_elem.text("ComponentSKU")
      # What we're looking for here is essentially any string of non-hyphen characters, followed by a hyphen
      # followed by 3 more characters.
      prepack_product_number = component_sku.match('(^\w+-)\w{3}').try :[], 0
      if prepack_product_number
        elem_arr = bom_sku_hash[prepack_product_number]
        if elem_arr.nil?
          elem_arr = []
          bom_sku_hash[prepack_product_number] = elem_arr
        end
        elem_arr << bom_component_elem
      else
        error_log.malformed_products << component_sku
      end
    end

    # The procedure above can result in dupe malformed product codes being added to the array.
    error_log.malformed_products.uniq!

    bom_sku_hash
  end

  def create_or_update_prepacks! prod, art_elem, changed, error_log
    article_number = prod.custom_value(cdefs[:prod_part_number])
    bom_sku_hash = create_bom_component_sku_hash art_elem, error_log

    bom_sku_hash.each do |prepack_product_number, bomcomponent_arr|
      prepack_product = Product.where(unique_identifier: "#{prod.importer.system_code}-#{prepack_product_number}", importer_id: prod.importer).first
      if prepack_product
        bomcomponent_arr.each do |bomcomponent_elem|
          component_sku = bomcomponent_elem.text("ComponentSKU")
          component_qty_text = bomcomponent_elem.text("ComponentQty")
          component_qty = component_qty_text ? BigDecimal(component_qty_text) : 0
          matching_variant = prepack_product.variants.find { |i| i.variant_identifier == component_sku }
          if matching_variant
            create_or_update_one_variant! matching_variant.variant_identifier, prod, get_variant_custom_values(matching_variant), changed, component_qty
          else
            missing_var = PrepackErrorLogMissingVariant.new article_number, prepack_product_number, component_sku
            error_log.missing_variants << missing_var
          end
        end
      else
        # This means that a particular component of a prepack has not been sent to us.
        error_log.missing_products << PrepackErrorLogMissingProduct.new(article_number, prepack_product_number)
      end
    end

    # Flag the product as a prepack.
    if !prod.custom_value(cdefs[:prod_prepack])
      prod.update_custom_value!(cdefs[:prod_prepack], true)
      changed.value = true
    end
  end

  class PrepackErrorLog
    attr_accessor :missing_products
    attr_accessor :missing_variants
    attr_accessor :malformed_products

    def initialize
      @missing_products = []
      @missing_variants = []
      @malformed_products = []
    end

    def has_errors?
      @missing_products.length > 0 || @missing_variants.length > 0 || @malformed_products.length > 0
    end
  end

  PrepackErrorLogMissingProduct = Struct.new(:article, :product)
  PrepackErrorLogMissingVariant = Struct.new(:article, :product, :variant)

  def get_variant_custom_values variant
    upc = variant.custom_value(cdefs[:var_upc])
    article_number = variant.custom_value(cdefs[:var_article_number])
    description = variant.custom_value(cdefs[:var_description])
    hts_code = variant.custom_value(cdefs[:var_hts_code])
    { var_upc: upc, var_article_number: article_number, var_description: description, var_hts_code: hts_code }
  end

  def set_var_custom_values! var, fields, changed
    custom_field_set = false
    fields.each do |key, value|
      old_val = var.custom_value(cdefs[key])
      if old_val != value
        var.find_and_set_custom_value(cdefs[key], value)
        custom_field_set = true
        changed.value = true
      end
      var.save! if custom_field_set
    end
  end

  def extract_var_opt_fields upc_elem
    var_hts_code = upc_elem.text("UPCAttr/Code[@Type='HTSCode']").try(:delete, ".")
    var_upc = upc_elem.text("UPCNumber")
    var_article_number = upc_elem.text("VariantArticle")
    var_description = upc_elem.text("VariantDescription")
    {var_upc: var_upc, var_article_number: var_article_number, var_description: var_description, var_hts_code: var_hts_code}
  end

  def create_or_update_classi! prod, customs_descr, var_hts_codes, changed
    ca_class = prod.classifications.select{ |cl| cl.country_id == ca.id }.first || prod.classifications.new(country_id: ca.id)
    if ca_class.persisted?
      unless ca_class.get_custom_value(cdefs[:class_customs_description]).value == customs_descr
        ca_class.update_custom_value!(cdefs[:class_customs_description], customs_descr)
        changed.value = true
      end
    else
      ca_class.save!
      ca_class.update_custom_value!(cdefs[:class_customs_description], customs_descr)
      changed.value = true
    end
    create_or_update_tariff! ca_class, var_hts_codes, changed
  end

  def create_or_update_tariff! ca_class, var_hts_codes, changed
    if var_hts_codes.count == 1
      hts = var_hts_codes.first
      tr = ca_class.tariff_records.first_or_initialize
      unless tr.hts_1 == hts
        tr.hts_1 = hts
        tr.save!
        changed.value = true
      end
    elsif var_hts_codes.count > 1
      tr = ca_class.tariff_records.try(:first)
      if tr
        tr.destroy
        changed.value = true
      end
    end
  end

  def pluck_unique_hts_values prod
    hts_list = []
    prod.variants.each { |var| hts_list << var.custom_value(cdefs[:var_hts_code]) }
    hts_list.uniq
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number, :var_upc, :var_article_number, :var_description, :var_hts_code, :class_customs_description, :prod_prepack, :var_units_per_inner_pack]
  end

  def system_code
    @system_code ||= MasterSetup.get.custom_feature?("UAPARTS Staging") ? "UAPARTS" : "UNDAR"
  end

  def ca
    @ca ||= Country.where(iso_code: "CA").first
    raise "Failed to find Canada." unless @ca
    @ca
  end

  def user
    @user ||= User.integration
  end

  def importer
    @importer ||= Company.where(system_code: system_code, importer: true).first
    raise "Failed to find Under Armour Importer account with system code: #{system_code}" unless @importer
    @importer
  end

end; end; end; end