require 'open_chain/custom_handler/alliance_product_support'
require 'open_chain/custom_handler/product_generator'
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
    ecs_connect_vfitrack_net('kewill_edi/to_kewill')
  end

  def sync_code
    'Alliance'
  end

  def initialize alliance_customer_number, opts = {}
    opts = opts.with_indifferent_access
    @alliance_customer_number = alliance_customer_number
    @importer_system_code = opts[:importer_system_code]
    @custom_where = opts[:custom_where]
    @strip_leading_zeros = opts[:strip_leading_zeros].to_s.to_boolean
    @use_unique_identifier = opts[:use_unique_identifier].to_s.to_boolean
    # Combined with the use_inique_identifier flag, this allows us to run this on customer specific systems
    # (like DAS) where the products aren't linked to any importer - since the whole system is a single importer's system.
    @disable_importer_check = opts[:disable_importer_check].to_s.to_boolean
    @allow_blank_tariffs = opts[:allow_blank_tariffs].to_s.to_boolean
    @allow_multiple_tariffs = opts[:allow_multiple_tariffs].to_s.to_boolean
    @default_values = opts[:defaults].presence || {}
    @disable_special_tariff_lookup = opts[:disable_special_tariff_lookup].to_s.to_boolean
    @default_special_tariff_country_origin = opts[:default_special_tariff_country_origin]
    @allow_style_truncation = opts[:allow_style_truncation].to_s.to_boolean
  end

  def custom_defs
    @cdefs ||= self.class.prep_custom_definitions [:prod_country_of_origin, :prod_part_number, :prod_fda_product, :prod_fda_product_code, :prod_fda_temperature, :prod_fda_uom, 
                :prod_fda_country, :prod_fda_mid, :prod_fda_shipper_id, :prod_fda_description, :prod_fda_establishment_no, :prod_fda_container_length, 
                :prod_fda_container_width, :prod_fda_container_height, :prod_fda_contact_name, :prod_fda_contact_phone, :prod_fda_affirmation_compliance, :prod_fda_affirmation_compliance_value, :prod_brand,
                :prod_301_exclusion_tariff]
    @cdefs
  end

  def sync_xml
    imp = nil
    if !@disable_importer_check
      imp = importer
    end
    
    val = super
    imp.update_attributes!(:last_alliance_product_push_at => Time.zone.now) if imp
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
    write_data(p, "styleNo", row[0], 40, error_on_trim: !@allow_style_truncation)
    write_data(p, "descr", row[1].to_s.upcase, 40)
    write_data(p, "countryOrigin", row[3], 2)
    # This is blanked unless FDA Flag is true, so we're ok to always send it (see preprocess_row)
    write_data(p, "manufacturerId", row[9], 15)
    write_data(p, "productLine", row[4], 30)
    append_defaults(p, "CatCiLine")
    
    classification_list_element = add_element(p, "CatTariffClassList")

    tariffs(row).each_with_index do |hts, index|
      tariff_seq = index + 1
      tariff_class = write_tariff classification_list_element, hts, tariff_seq, row

      if row[5] == "Y"
        fda = add_element(add_element(tariff_class, "CatFdaEsList"), "CatFdaEs")
        add_kewill_keys fda, row
        # This is the CatTariffClass "key"...whoever designed this XML was dumb.
        add_element(fda, "seqNo", tariff_seq)
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
        append_defaults(fda, "CatFdaEs")

        if !row[18].blank?
          aff_comp = add_element(add_element(fda, "CatFdaEsComplianceList"), "CatFdaEsCompliance")
          add_kewill_keys(aff_comp, row)
          add_element(aff_comp, "seqNo", "1")
          add_element(aff_comp, "fdaSeqNo", "1")
          add_element(aff_comp, "seqNoEntryOrder", "1")
          write_data(aff_comp, "complianceCode", row[18], 3)
          # It appears Kewill named qualifier incorrectly...as the qualifier is actually the affirmation of compliance number/value
          write_data(aff_comp, "complianceQualifier", row[19], 25)
          append_defaults(aff_comp, "CatFdaEsCompliance")
        end
      end
    end
  end

  def write_tariff parent_element, hts, sequence, row
    tariff_class = add_element(parent_element, "CatTariffClass")
    add_kewill_keys(tariff_class, row)
    add_element(tariff_class, "seqNo", sequence)

    # Since we're allowing blank tariffs, just take part of the join condition for 8 char tariffs and recreate it here, dropping
    # anything that's less than 8 chars (.ie not a good tariff)
    write_data(tariff_class, "tariffNo", (hts.to_s.length >= 8 ? hts : ""), 10, error_on_trim: true)
    append_defaults(tariff_class, "CatTariffClass")

    tariff_class
  end

  def xml_document_and_root_element
    doc, kc_data = create_document category: "Parts", subAction: "CreateUpdate"
    parts = add_element(kc_data, "parts")
    [doc, parts]
  end

  def add_kewill_keys parent, row, include_style: true
    write_data(parent, "custNo", @alliance_customer_number, 10, error_on_trim: true)
    write_data(parent, "partNo", row[0], 40, error_on_trim: !@allow_style_truncation)
    write_data(parent, "styleNo", row[0], 40, error_on_trim: !@allow_style_truncation) if include_style
    write_data(parent, "dateEffective", date_format(effective_date), 8, error_on_trim: true)
  end

  def append_defaults parent, level
    defaults = @default_values[level]
    return if defaults.blank?
    defaults.each_pair do |name, value|
      add_element(parent, name, value)
    end
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

  def importer
    if !@importer_system_code.blank?
      @importer ||= Company.where(system_code: @importer_system_code).first
      raise ArgumentError, "No importer found with Importer System Code '#{@importer_system_code}'." unless @importer
    else
      @importer ||= Company.with_customs_management_number(@alliance_customer_number).first
      raise ArgumentError, "No importer found with Kewill customer number '#{@alliance_customer_number}'." unless @importer
    end

    @importer
  end

  def query
    qry = <<-QRY
SELECT products.id,
#{@use_unique_identifier ? "products.unique_identifier" : cd_s(custom_defs[:prod_part_number].id)},
products.name,
#{@allow_multiple_tariffs ? "(SELECT GROUP_CONCAT(hts_1 ORDER BY line_number SEPARATOR '*~*') FROM tariff_records tar WHERE tar.classification_id = classifications.id and length(tar.hts_1) >= 8 )" : "(SELECT tar.hts_1 FROM tariff_records tar WHERE tar.classification_id = classifications.id and length(tar.hts_1) >= 8 and tar.line_number = 1)" },
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
#{cd_s custom_defs[:prod_fda_temperature].id},
#{cd_s custom_defs[:prod_301_exclusion_tariff]}
FROM products
INNER JOIN classifications on classifications.country_id = (SELECT id FROM countries WHERE iso_code = "US") AND classifications.product_id = products.id
QRY

    if @custom_where.blank?
      qry += "#{Product.need_sync_join_clause(sync_code)} 
WHERE 
#{Product.need_sync_where_clause()} "
    else 
      qry += "WHERE #{@custom_where} "
    end
    
    qry += " AND length(#{cd_s custom_defs[:prod_part_number].id, suppress_alias: true})>0" unless @use_unique_identifier
    qry += " AND products.importer_id = #{importer.id}" unless @disable_importer_check


    unless @allow_blank_tariffs
      qry += " AND LENGTH((SELECT GROUP_CONCAT(hts_1 ORDER BY line_number SEPARATOR '#{tariff_separator}') FROM tariff_records tar WHERE tar.classification_id = classifications.id and length(tar.hts_1) >= 8)) >= 0"
    end
    
    if @custom_where.blank?
      # Now that we're using XML, documents get really big, really quickly...so limit to X at a time per file
      qry += " LIMIT #{max_products_per_file}"
    end

    qry
  end

  def tariff_separator
    "*~*"
  end

  def tariffs row
    # We're concat'ing all the product's US tariffs into a single field in the SQL query and then splitting them out
    # here into individual classification fields.
    product_tariffs = row[2].to_s.split(tariff_separator)
    
    exclusion_301_tariff = exclusion_301_tariff(row).to_s.strip.gsub(".", "")

    exclude_301_tariffs = exclusion_301_tariff.present?

    # Find any special tariffs we should add into the tariff list
    additional_tariffs = []
    product_tariffs.each do |t|
      # row[3] = Country of origin
      additional_tariffs.push *special_tariff_numbers(row[3], t, exclude_301_tariffs)
    end

    # Now we need to see if any of the tariffs on the product record are "special" ones already.
    # For example, customers are feeding us MTB tariffs, which are special ones we can't include automatically in the feed (in the case
    # of MTB, there's not a 1-1 mapping between the standard HTS and MTB code)
    keyed_special_tariffs = []
    standard_tariffs = []
    product_tariffs.each do |t|
      # Determine the priority that should be applied to any special tariffs that were keyed by the user.  Typically this is going to 
      # be MTB tariffs (as opposed to 301 tariffs), as we don't automatically add MTB tariffs.
      priority = keyed_special_tariff_priority(row[3], t)
      if priority.nil?
        standard_tariffs << t
      else
        keyed_special_tariffs << {priority: priority, tariff: t}
      end
    end

    # Keyed special tariffs should always come before the "standard" tariff...i'm not 100% sure this is a hard/fast rule but 
    # for now we'll treat it like it is.  If that's not always the case what we COULD do is base the priority around positive numbers appearing
    # before the standard tariff and negatives after it.
    # For now, the higher the priority, the closer to the front of the special list
    sorted_keyed_special_tariffs = keyed_special_tariffs.sort_by {|t| t[:priority] }.map {|t| t[:tariff] }.reverse

    hts_values = []
    # The exclusion should always come first
    hts_values << exclusion_301_tariff unless exclusion_301_tariff.blank?
    hts_values.push *additional_tariffs
    hts_values.push *sorted_keyed_special_tariffs
    hts_values.push *standard_tariffs

    hts_values.uniq
  end

  def special_tariff_numbers product_country_origin, hts_number, exclude_301_tariffs
    return [] if hts_number.blank? || @disable_special_tariff_lookup

    country_origin = (product_country_origin.presence || @default_special_tariff_country_origin).to_s

    tariffs = special_tariff_hash.tariffs_for(country_origin, hts_number)
    tariffs.delete_if {|t| t.special_tariff_type.to_s.strip == "301" } if exclude_301_tariffs

    tariffs.map &:special_hts_number
  end

  def special_tariff_hash
    @special_tariffs ||= SpecialTariffCrossReference.find_special_tariff_hash "US", true, reference_date: Time.zone.now.to_date
  end

  def keyed_special_tariff_priority product_country_origin, hts_number
    tariff = special_tariff_numbers_hash.tariffs_for(product_country_origin, hts_number)&.first
    priority = nil
    if tariff
      priority = tariff.priority.to_i
    end

    priority
  end

  def special_tariff_numbers_hash
    # Because these are tariffs that aren't automatically included, into the feed we pass false below to get ALL the special tariff numbers.
    # We also want to key the hash by the special number, not the standard number.
    @special_tariff_numbers_hash ||= SpecialTariffCrossReference.find_special_tariff_hash("US", false, reference_date: Time.zone.now.to_date, use_special_number_as_key: true)
  end

  def exclusion_301_tariff row
    row[21]
  end

end; end; end; end