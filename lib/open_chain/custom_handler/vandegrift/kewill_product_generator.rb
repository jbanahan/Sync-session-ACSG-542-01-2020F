require 'open_chain/custom_handler/alliance_product_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/vandegrift/kewill_web_services_support'

module OpenChain; module CustomHandler; module Vandegrift; class KewillProductGenerator < OpenChain::CustomHandler::ProductGenerator
  include OpenChain::CustomHandler::AllianceProductSupport
  include OpenChain::CustomHandler::Vandegrift::KewillWebServicesSupport
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.run_schedulable opts = {}
    opts = opts.with_indifferent_access
    sync opts['alliance_customer_number'], opts
  end

  def self.sync alliance_customer_number, opts = {}
    g = self.new alliance_customer_number, opts
    f = nil
    begin
      f = g.sync_xml
      g.ftp_file(f) unless f.nil?
    ensure
      f.close! unless f.nil? || f.closed?
    end while !f.nil? && !opts[:no_loop]
    nil
  end

  def ftp_credentials
    connect_vfitrack_net('to_ecs/kewill_products')
  end

  def sync_code
    'Alliance'
  end

  def initialize alliance_customer_number, opts = {}
    @alliance_customer_number = alliance_customer_number
    @custom_where = opts[:custom_where]
    @strip_leading_zeros = opts[:strip_leading_zeros].to_s.to_boolean
    @use_unique_identifier = opts[:use_unique_identifier].to_s.to_boolean
    # Combined with the use_inique_identifier flag, this allows us to run this on customer specific systems
    # (like DAS) where the products aren't linked to any importer - since the whole system is a single importer's system.
    @disable_importer_check = opts[:disable_importer_check].to_s.to_boolean
  end

  def custom_defs
    @cdefs ||= self.class.prep_custom_definitions [:prod_country_of_origin, :prod_part_number, :prod_fda_product, :prod_fda_product_code, :prod_fda_temperature, :prod_fda_uom, 
                :prod_fda_country, :prod_fda_mid, :prod_fda_shipper_id, :prod_fda_description, :prod_fda_establishment_no, :prod_fda_container_length, 
                :prod_fda_container_width, :prod_fda_container_height, :prod_fda_contact_name, :prod_fda_contact_phone, :prod_fda_affirmation_compliance, :prod_fda_affirmation_compliance_value, :prod_brand]
    @cdefs
  end

  def sync_xml
    if !@disable_importer_check
      @importer ||= Company.where(alliance_customer_number: @alliance_customer_number).first
      raise ArgumentError, "No importer found with Kewill customer number '#{@alliance_customer_number}'." unless @importer
    end
    
    val = super
    @importer.update_attributes!(:last_alliance_product_push_at => Time.zone.now) if @importer
    val
  end

  def preprocess_row row, opts = {}
    if @strip_leading_zeros 
      row[0] = row[0].to_s.gsub(/^0+/, "")
    end

    # We're going to exclude all the FDA columns unless the FDA Product indicator is true
    unless row[5] == "Y"
      (5..18).each {|x| row[x] = ""}
    end

    super row, opts
  end

  def write_row_to_xml parent, row_counter, row
    p = add_element(parent, "part")
    add_kewill_keys(add_element(p, "id"), row, include_style: false)
    # Without this expiration, the product ci line data can't be pulled in.
    # Guessing they're doing a check over effective date and expiration date columns in their tables
    # to determine which record to utilize for a part.
    add_element(p, "dateExpiration", "20991231") 
    write_data(p, "styleNo", row[0], 40, error_on_trim: true)
    write_data(p, "descr", row[1], 40)
    write_data(p, "countryOrigin", row[3], 2)
    # This is blanked unless FDA Flag is true, so we're ok to always send it (see preprocess_row)
    write_data(p, "manufacturerId", row[9], 15)
    write_data(p, "productLine", row[4], 30)

    # If we ever add the ability to add multiple HTS #'s, this bit becomes a loop over the HTS values
    # and each successive one has an incrementing sequence number (not entirely sure how things like FDA work though)
    tariff_class = add_element(add_element(p, "CatTariffClassList"), "CatTariffClass")
    add_kewill_keys(tariff_class, row)
    add_element(tariff_class, "seqNo", "1")
    write_data(tariff_class, "tariffNo", row[2], 10, error_on_trim: true)

    if row[5] == "Y"
      fda = add_element(add_element(tariff_class, "CatFdaEsList"), "CatFdaEs")
      add_kewill_keys fda, row
      # This is the CatTariffClass "key"...whoever designed this XML was dumb.
      add_element(fda, "seqNo", "1")
      add_element(fda, "fdaSeqNo", "1")
      write_data(fda, "productCode", row[6], 7)
      write_data(fda, "fdaUom1", row[7], 4)
      write_data(fda, "countryProduction", row[8], 2)
      write_data(fda, "manufacturerId", row[9], 15)
      write_data(fda, "shipperId", row[10], 15)
      write_data(fda, "desc1Ci", row[11], 70)
      write_data(fda, "establishmentNo", row[12], 12)
      write_data(fda, "containerDimension1", row[13], 4)
      write_data(fda, "containerDimension2", row[14], 4)
      write_data(fda, "containerDimension3", row[15], 4)
      write_data(fda, "contactName", row[16], 10)
      write_data(fda, "contactPhone", row[17], 10)
      write_data(fda, "cargoStorageStatus", row[20], 1)
      if !row[18].blank?
        aff_comp = add_element(add_element(fda, "CatFdaEsComplianceList"), "CatFdaEsCompliance")
        add_kewill_keys(aff_comp, row)
        add_element(aff_comp, "seqNo", "1")
        add_element(aff_comp, "fdaSeqNo", "1")
        add_element(aff_comp, "seqNoEntryOrder", "1")
        write_data(aff_comp, "complianceCode", row[18], 3)
        # It appears Kewill named qualifier incorrectly...as the qualifier is actually the affirmation of compliance number/value
        write_data(aff_comp, "complianceQualifier", row[19], 25)
      end
    end
  end

  def xml_document_and_root_element
    doc, kc_data = create_document category: "Parts", subAction: "CreateUpdate"
    parts = add_element(kc_data, "parts")
    [doc, parts]
  end

  def add_kewill_keys parent, row, include_style: true
    write_data(parent, "custNo", @alliance_customer_number, 10, error_on_trim: true)
    write_data(parent, "partNo", row[0], 40, error_on_trim: true)
    write_data(parent, "styleNo", row[0], 40, error_on_trim: true) if include_style
    write_data(parent, "dateEffective", date_format(effective_date), 8, error_on_trim: true)
  end

  def effective_date
    Date.new(2014, 1, 1)
  end

  def max_products_per_file
    500
  end

  def write_data(parent, element_name, data, max_length, allow_blank: false, error_on_trim: false)

    if data && data.to_s.length > max_length
      # There's a few values we never want to truncate, hence the check here.  Those are mostly only just primary key fields in Kewill
      # that we never want to truncate.
      raise "#{element_name} cannot be over #{max_length} characters.  It was '#{data.to_s}'." if error_on_trim
      data = data.to_s[0, max_length]
    end

    add_element parent, element_name, data, allow_blank: allow_blank
  end

  def date_format date
    date ? date.strftime("%Y%m%d") : nil
  end

  def query
    qry = <<-QRY
SELECT products.id,
#{@use_unique_identifier ? "products.unique_identifier" : cd_s(custom_defs[:prod_part_number].id)},
products.name,
tariff_records.hts_1,
IF(length(#{cd_s custom_defs[:prod_country_of_origin].id, suppress_alias: true})=2,#{cd_s custom_defs[:prod_country_of_origin].id, suppress_alias: true},""),
#{cd_s custom_defs[:prod_brand].id},
#{cd_s(custom_defs[:prod_fda_product].id, boolean_y_n: true)},
#{cd_s custom_defs[:prod_fda_product_code].id},
#{cd_s custom_defs[:prod_fda_uom].id},
#{cd_s custom_defs[:prod_fda_country].id},
#{cd_s custom_defs[:prod_fda_mid].id},
#{cd_s custom_defs[:prod_fda_shipper_id].id},
#{cd_s custom_defs[:prod_fda_description].id},
#{cd_s custom_defs[:prod_fda_establishment_no].id},
#{cd_s custom_defs[:prod_fda_container_length].id},
#{cd_s custom_defs[:prod_fda_container_width].id},
#{cd_s custom_defs[:prod_fda_container_height].id},
#{cd_s custom_defs[:prod_fda_contact_name].id},
#{cd_s custom_defs[:prod_fda_contact_phone].id},
#{cd_s custom_defs[:prod_fda_affirmation_compliance].id},
#{cd_s custom_defs[:prod_fda_affirmation_compliance_value].id},
#{cd_s custom_defs[:prod_fda_temperature].id} 
FROM products
INNER JOIN classifications on classifications.country_id = (SELECT id FROM countries WHERE iso_code = "US") AND classifications.product_id = products.id
INNER JOIN tariff_records on length(tariff_records.hts_1) >= 8 AND tariff_records.classification_id = classifications.id AND tariff_records.line_number = 1
QRY
    if @custom_where.blank?
      qry += "#{Product.need_sync_join_clause(sync_code)} 
WHERE 
#{Product.need_sync_where_clause()} "
    else 
      qry += "WHERE #{@custom_where} "
    end
    
    qry += " AND length(#{cd_s custom_defs[:prod_part_number].id, suppress_alias: true})>0"
    qry += " AND products.importer_id = #{@importer.id}" unless @disable_importer_check

    
    if @custom_where.blank?
      # Now that we're using XML, documents get really big, really quickly...so limit to X at a time per file
      qry += " LIMIT #{max_products_per_file}"
    end

    qry
  end
end; end; end; end