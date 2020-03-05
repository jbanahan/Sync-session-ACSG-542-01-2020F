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
    end while !f.nil? && !(opts[:no_loop] || opts[:custom_where].present?)
    nil
  end

  attr_reader :alliance_customer_number, :customer_numbers, :importer_system_code, :default_values, :default_special_tariff_country_origin

  def initialize alliance_customer_number, opts = {}
    opts = opts.with_indifferent_access
    super(opts)

    # Combined with the use_inique_identifier flag, this allows us to run this on customer specific systems
    # (like DAS) where the products aren't linked to any importer - since the whole system is a single importer's system.
    add_options(opts, :include_linked_importer_products, :strip_leading_zeros, :use_unique_identifier, :disable_importer_check,
                      :allow_blank_tariffs, :allow_multiple_tariffs, :disable_special_tariff_lookup, :allow_style_truncation,
                      :suppress_fda_data)
    # We can allow for multiple customer numbers so that we can just have a single scheduled job for all the simple 
    # generators that share the same setup (just with different customer numbers)
    if opts[:customer_numbers]
      @customer_numbers = Array.wrap(opts[:customer_numbers])
      # Make sure disable_importer_check is never accidently enabled when customer_numbers is used - otherwise the feed blows up
      add_options({disable_importer_check: true, use_customer_numbers: true}, :disable_importer_check, :use_customer_numbers)
    else
      @alliance_customer_number = alliance_customer_number
    end
    @importer_system_code = opts[:importer_system_code]

    @default_values = opts[:defaults].presence || {}
    @default_special_tariff_country_origin = opts[:default_special_tariff_country_origin]
  end

  class ProductData
    attr_accessor :customer_number, :part_number, :effective_date, :expiration_date, :description, :country_of_origin, :mid, :product_line, :exclusion_301_tariff, 
                  :tariff_data, :fda_data, :penalty_data
  end

  # This is CVD / ADD data
  class PenaltyData
    # penalty_type should be CVD or ADA (for ADD cases)
    attr_accessor :penalty_type, :case_number
  end

  class TariffData
    attr_accessor :tariff_number, :priority, :secondary_priority, :primary_tariff, :special_tariff, :spi, :lacey_data

    def initialize tariff_number, priority, secondary_priority, primary_tariff, special_tariff
      @tariff_number = tariff_number
      @priority = priority
      @secondary_priority = secondary_priority
      @primary_tariff = primary_tariff
      @special_tariff = special_tariff
    end

  end

  class FdaData
    attr_accessor :product_code, :uom, :country_production, :mid, :shipper_id, :description, :establishment_number, :container_dimension_1,
                  :container_dimension_2, :container_dimension_3, :contact_name, :contact_phone, :cargo_storage_status, :affirmations_of_compliance,
                  :accession_number
  end

  class FdaAffirmationOfComplianceData
    attr_accessor :code, :qualifier
  end

  class LaceyData
    attr_accessor :preparer_name, :preparer_email, :preparer_phone, :components
  end

  class LaceyComponentData
    attr_accessor :component_of_article, :country_of_harvest, :quantity, :quantity_uom, :percent_recycled, :scientific_names
  end

  class LaceyScientificNames
    attr_accessor :genus, :species
  end

  def custom_defs
    @cdefs ||= self.class.prep_custom_definitions [:prod_country_of_origin, :prod_part_number, :prod_fda_product, :prod_fda_product_code, :prod_fda_temperature, :prod_fda_uom, 
                :prod_fda_country, :prod_fda_mid, :prod_fda_shipper_id, :prod_fda_description, :prod_fda_establishment_no, :prod_fda_container_length, 
                :prod_fda_container_width, :prod_fda_container_height, :prod_fda_contact_name, :prod_fda_contact_phone, :prod_fda_affirmation_compliance, :prod_fda_affirmation_compliance_value, :prod_brand,
                :prod_301_exclusion_tariff, :prod_fda_accession_number, :prod_cvd_case, :prod_add_case, :class_special_program_indicator, :prod_lacey_component_of_article, :prod_lacey_genus_1, :prod_lacey_species_1, :prod_lacey_genus_2, 
                :prod_lacey_species_2, :prod_lacey_country_of_harvest, :prod_lacey_quantity, :prod_lacey_quantity_uom, :prod_lacey_percent_recycled, :prod_lacey_preparer_name, :prod_lacey_preparer_email, :prod_lacey_preparer_phone]
    @cdefs
  end

  def ftp_credentials
    ecs_connect_vfitrack_net('kewill_edi/to_kewill')
  end

  def sync_code
    'Alliance'
  end

  def sync_xml
    imp = importer unless has_option?(:disable_importer_check)
    val = super
    imp.update!(:last_alliance_product_push_at => Time.zone.now) if imp
    val
  end

  def write_row_to_xml parent, row_counter, row
    data = map_query_row_to_product_data(row)

    p = add_element(parent, "part")
    add_kewill_keys(add_element(p, "id"), data, include_style: false)
    add_part_data(p, data)
    append_defaults(p, "CatCiLine")

    if Array.wrap(data.tariff_data).length > 0
      classification_list_element = add_element(p, "CatTariffClassList")

      Array.wrap(data.tariff_data).each_with_index do |tariff_data, index|
        tariff_seq = index + 1
        tariff_class = add_element(classification_list_element, "CatTariffClass")
        add_kewill_keys(tariff_class, data)
        add_element(tariff_class, "seqNo", tariff_seq)
        add_tariff_data(tariff_class, tariff_data, tariff_seq, row)
        append_defaults(tariff_class, "CatTariffClass")

        # All the PGA data should go on the primary tariff row and nothing else
        next unless tariff_data.primary_tariff

        if Array.wrap(data.fda_data).length > 0
          fda_es_list = add_element(tariff_class, "CatFdaEsList")
          Array.wrap(data.fda_data).each_with_index do |fda_data, fda_index|
            fda_seq = fda_index + 1

            fda = add_element(fda_es_list, "CatFdaEs")
            add_kewill_keys fda, data

            # This is the CatTariffClass "key"...whoever designed this XML was dumb.
            add_element(fda, "seqNo", tariff_seq)
            add_element(fda, "fdaSeqNo", fda_seq)
            add_fda_data(fda, fda_data)
            append_defaults(fda, "CatFdaEs")

            if Array.wrap(fda_data.affirmations_of_compliance).length > 0
              fda_aff_list = add_element(fda, "CatFdaEsComplianceList")

              Array.wrap(fda_data.affirmations_of_compliance).each_with_index do |aff_data, aff_index|
                aff_seq = aff_index + 1

                aff_comp = add_element(fda_aff_list, "CatFdaEsCompliance")
                add_kewill_keys(aff_comp, data)
                add_element(aff_comp, "seqNo", tariff_seq)
                add_element(aff_comp, "fdaSeqNo", fda_seq)
                add_element(aff_comp, "seqNoEntryOrder", aff_seq)
                add_fda_affirmation_of_compliance(aff_comp, aff_data)
                append_defaults(aff_comp, "CatFdaEsCompliance")
              end
            end
          end
        end

        if Array.wrap(tariff_data.lacey_data).length > 0
          pg_es_list = add_element(tariff_class, "CatPgEsList")

          product_seq_number = 1
          Array.wrap(tariff_data.lacey_data).each_with_index do |lacey, lacey_index|
            pg_seq_number = lacey_index + 1

            pg = add_element(pg_es_list, "CatPgEs")
            add_kewill_keys pg, data
            add_element(pg, "seqNo", tariff_seq)
            add_element(pg, "pgCd", "AL1")
            add_element(pg, "pgAgencyCd", "APH")
            add_element(pg, "pgProgramCd", "APL")
            add_element(pg, "pgSeqNbr", pg_seq_number)

            aphis_es = add_element(pg, "CatPgAphisEs")
            add_kewill_keys aphis_es, data
            add_element(aphis_es, "seqNo", tariff_seq)
            add_element(aphis_es, "pgCd", "AL1")
            add_element(aphis_es, "pgAgencyCd", "APH")
            add_element(aphis_es, "pgProgramCd", "APL")
            add_element(aphis_es, "pgSeqNbr", pg_seq_number)
            add_element(aphis_es, "productSeqNbr", product_seq_number)

            add_lacey_data(aphis_es, lacey)

            if Array.wrap(lacey.components).length > 0
              pg_components_list = add_element(aphis_es, "CatPgAphisEsComponentsList")

              Array.wrap(lacey.components).each_with_index do |component, component_index|
                component_seq_number = component_index + 1

                comp = add_element(pg_components_list, "CatPgAphisEsComponents")
                add_kewill_keys comp, data
                add_element(comp, "seqNo", tariff_seq)
                add_element(comp, "pgCd", "AL1")
                add_element(comp, "pgSeqNbr", pg_seq_number)
                add_element(comp, "productSeqNbr", product_seq_number)
                add_element(comp, "componentSeqNbr", component_seq_number)

                add_lacey_component_data(comp, component)

                # The first scentific name is sent on the lacey component data, we'll send
                # the second on a sub list
                if Array.wrap(component.scientific_names).length > 1
                  scientific_list = add_element(comp, "CatPgAphisEsAddScientificList")

                  Array.wrap(component.scientific_names)[1..-1].each_with_index do |scientific_name, scientific_index|
                    scientific_seq_no = scientific_index + 1
                    science = add_element(scientific_list, "CatPgAphisEsAddScientific")

                    add_kewill_keys science, data
                    add_element(science, "seqNo", tariff_seq)
                    add_element(science, "pgCd", "AL1")
                    add_element(science, "pgSeqNbr", pg_seq_number)
                    add_element(science, "productSeq", product_seq_number)
                    add_element(science, "componentSeqNbr", component_seq_number)
                    add_element(science, "scientificSeqNbr", scientific_seq_no)

                    add_lacey_scientific_name(science, scientific_name)
                  end
                end
              end
            end
          end
        end
      end

      if Array.wrap(data.penalty_data).length > 0
        penalty_list_element = add_element(p, "CatPenaltyList")
        Array.wrap(data.penalty_data).each do |penalty_data|
          cat_penalty = add_element(penalty_list_element, "CatPenalty")
          add_kewill_keys(cat_penalty, data, include_style: true)
          add_penalty_data(cat_penalty, penalty_data)
        end
      end
    end
  end

  def map_query_row_to_product_data row
    d = ProductData.new
    map_product_header_data(d, row)
    d.tariff_data = map_tariff_number_data(d, row)
    d.fda_data = map_fda_data(d, row)
    d.penalty_data = map_penalty_data(d, row)

    d
  end

  # This method provides the mapping for the base product header mapping that pretty much any 
  # generator that extends this class almost certainly should be utilizing.
  def base_product_header_mapping d, row
    # The query should be pulling the Customs Management cust_no from the system identifiers table now, it's possible on some customer 
    # systems that this won't be present, so just fall back to using the customer number set up from the constructor.
    d.customer_number = customer_number(row).presence || self.alliance_customer_number
    d.part_number = part_number(row)
    d.part_number = d.part_number.to_s.gsub(/^0+/, "") if has_option?(:strip_leading_zeros)
    d.effective_date = effective_date
    # Without this expiration, the product ci line data can't be pulled in.
    # Guessing they're doing a check over effective date and expiration date columns in their tables
    # to determine which record to utilize for a part.
    d.expiration_date = expiration_date
  end

  def map_product_header_data d, row
    base_product_header_mapping(d, row)

    d.description = row[1].to_s.upcase
    d.country_of_origin = row[3]
    d.mid = validate_mid(row)
    d.product_line = row[4]
    d.exclusion_301_tariff = exclusion_301_tariff(row)
    
    nil
  end

  def map_tariff_number_data product, row
    tariff_data = tariffs(product, row)
    spi = row[27]

    if spi.present?
      set_value_in_tariff_data(tariff_data, "spi", spi)
    end

    primary_tariff = find_primary_tariff(tariff_data)
    if primary_tariff
      primary_tariff.lacey_data = map_lacey_data(product, primary_tariff, row)
    end

    tariff_data
  end

  # Because some field values may have to be applied across multiple tariffs that may have dynmically 
  # been added, this method exists to make this easier to do
  def set_value_in_tariff_data tariffs, field_name, value, primary_tariff_only: true, skip_special_tariffs: true
    tariffs.each do |tariff|
      next if primary_tariff_only && !tariff.primary_tariff
      next if skip_special_tariffs && tariff.special_tariff

      tariff.public_send("#{field_name}=", value)
    end
  end

  def find_primary_tariff tariffs
    tariffs.find {|t| t.primary_tariff == true }
  end

  def has_fda_data? row
    row[5] == "Y" || row[6].present?
  end

  def has_fda_affirmation_of_compliance? row
    !row[18].blank?
  end

  def map_fda_data product, row
    if has_fda_data? row
      f = FdaData.new
      f.product_code = row[6]
      f.uom = row[7]
      f.country_production = row[8]
      f.mid = row[9]
      f.shipper_id = row[10]
      f.description = row[11]
      f.establishment_number = row[12]
      f.container_dimension_1 = row[13]
      f.container_dimension_2 = row[14]
      f.container_dimension_3 = row[15]
      f.contact_name = row[16]
      f.contact_phone = row[17]
      f.cargo_storage_status = row[20]
      f.affirmations_of_compliance = []

      if has_fda_affirmation_of_compliance?(row)
        c = FdaAffirmationOfComplianceData.new
        c.code = row[18]
        c.qualifier = row[19]
        f.affirmations_of_compliance << c
      end

      # The Accession Number is simply another Affirmation of Compliance value with a specific Code of ACC
      if row[21].present?
        c = FdaAffirmationOfComplianceData.new
        c.code = "ACC"
        c.qualifier = row[21]
        f.affirmations_of_compliance << c
      end

      return [f]
    else
      return []
    end
  end

  def map_penalty_data product, row
    penalties = []

    if row[25].present?
      d = PenaltyData.new
      d.penalty_type = "CVD"
      d.case_number = row[25]
      penalties << d
    end

    if row[26].present?
      d = PenaltyData.new
      d.penalty_type = "ADA"
      d.case_number = row[26]
      penalties << d
    end

    penalties
  end

  def map_lacey_data product, tariff, row
    lacey = []

    # If no component article exists, don't send lacey data
    if row[28].present?
      l = LaceyData.new
      l.preparer_name = row[29]
      l.preparer_email = row[30]
      l.preparer_phone = row[31]
      l.components = []

      c = LaceyComponentData.new
      l.components << c

      c.component_of_article = row[28]
      c.country_of_harvest = row[32]
      c.quantity = row[33]
      c.quantity_uom = row[34]
      c.percent_recycled = row[35]
      
      c.scientific_names = []

      if row[36].present? && row[37].present?
        s = LaceyScientificNames.new
        s.genus = row[36]
        s.species = row[37]

        c.scientific_names << s
      end

      if row[38].present? && row[39].present?
        s = LaceyScientificNames.new
        s.genus = row[38]
        s.species = row[39]
        
        c.scientific_names << s
      end

      lacey << l
    end

    lacey
  end

  def add_part_data part, data
    write_data(part, "styleNo", data.part_number, 40, error_on_trim: !has_option?(:allow_style_truncation))
    write_data(part, "descr", data.description.to_s.upcase, 40)
    write_data(part, "countryOrigin", data.country_of_origin, 2)
    write_data(part, "manufacturerId", data.mid, 15)
    write_data(part, "productLine", data.product_line, 30)
    write_data(part, "dateExpiration", date_format(data.expiration_date), 8, error_on_trim: true) 
    
    nil
  end

  def add_tariff_data tariff_class, tariff_data, sequence, row
    # Since we're allowing blank tariffs, just take part of the join condition for 8 char tariffs and recreate it here, dropping
    # anything that's less than 8 chars (.ie not a good tariff)
    write_data(tariff_class, "tariffNo", (tariff_data.tariff_number.to_s.length >= 8 ? tariff_data.tariff_number : ""), 10, error_on_trim: true)
    write_data(tariff_class, "spiPrimary", tariff_data.spi, 2) if tariff_data.spi.present?
    nil
  end

  def add_fda_data fda, data
    write_data(fda, "productCode", data.product_code, 7)
    write_data(fda, "fdaUom1", data.uom, 4)
    write_data(fda, "countryProduction", data.country_production, 2)
    write_data(fda, "manufacturerId", data.mid, 15)
    write_data(fda, "shipperId", data.shipper_id, 15)
    write_data(fda, "desc1Ci", data.description, 70)
    write_data(fda, "establishmentNo", data.establishment_number, 12)
    write_data(fda, "containerDimension1", data.container_dimension_1, 4)
    write_data(fda, "containerDimension2", data.container_dimension_2, 4)
    write_data(fda, "containerDimension3", data.container_dimension_3, 4)
    write_data(fda, "contactName", data.contact_name, 10)
    write_data(fda, "contactPhone", data.contact_phone, 10)
    write_data(fda, "cargoStorageStatus", data.cargo_storage_status, 1)

    nil
  end

  def add_fda_affirmation_of_compliance aff_comp, data
    write_data(aff_comp, "complianceCode", data.code, 3)
    # It appears Kewill named qualifier incorrectly...as the qualifier is actually the affirmation of compliance number/value
    write_data(aff_comp, "complianceQualifier", data.qualifier, 25)

    nil
  end

  def add_penalty_data cat_penalty, penalty_data
    write_data(cat_penalty, "penaltyType", penalty_data.penalty_type, 3)
    # Remove any hyphens and upcase in the ADD / CVD Case
    write_data(cat_penalty, "caseNo", penalty_data.case_number.to_s.gsub("-", "").upcase, 10)
    nil
  end

  def add_lacey_data parent, lacey
    write_data(parent, "importerIndividualName", lacey.preparer_name, 95)
    write_data(parent, "importerEmailAddress", lacey.preparer_email, 107)
    write_data(parent, "importerPhoneNo", lacey.preparer_phone, 15)

    nil
  end

  def add_lacey_component_data parent, component
    write_data(parent, "componentName", component.component_of_article, 51)
    write_data(parent, "componentQtyAmt", component.quantity, 13)
    write_data(parent, "componentUom", component.quantity_uom, 5)
    write_data(parent, "countryHarvested", component.country_of_harvest, 22)
    write_data(parent, "percentRecycledMaterialAmt", component.percent_recycled, 7)

    # This is broken down weirdly where the first scentific name is on the main component
    # element / db table, but then additional ones are on subelements / subtable
    scientific_name = Array.wrap(component.scientific_names).first
    if scientific_name
      add_lacey_scientific_name(parent, scientific_name)
    end

    nil
  end

  def add_lacey_scientific_name parent, scientific_name
    write_data(parent, "scientificGenusName", scientific_name.genus, 22)
    write_data(parent, "scientificSpeciesName", scientific_name.species, 22)
  end
  
  def xml_document_and_root_element
    doc, kc_data = create_document category: "Parts", subAction: "CreateUpdate"
    parts = add_element(kc_data, "parts")
    [doc, parts]
  end

  def add_kewill_keys parent, data, include_style: true
    write_data(parent, "custNo", data.customer_number, 10, error_on_trim: true)
    write_data(parent, "partNo", data.part_number, 40, error_on_trim: !has_option?(:allow_style_truncation))
    write_data(parent, "styleNo", data.part_number, 40, error_on_trim: !has_option?(:allow_style_truncation)) if include_style
    write_data(parent, "dateEffective", date_format(data.effective_date), 8, error_on_trim: true)
  end

  def append_defaults parent, level
    defaults = self.default_values[level]
    return if defaults.blank?
    defaults.each_pair do |name, value|
      add_element(parent, name, value)
    end
  end

  def effective_date
    Date.new(2014, 1, 1)
  end

  def expiration_date
    Date.new(2099, 12, 31)
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
    if !self.importer_system_code.blank?
      @importer ||= Company.where(system_code: self.importer_system_code).first
      raise ArgumentError, "No importer found with Importer System Code '#{self.importer_system_code}'." unless @importer
    else
      @importer ||= Company.with_customs_management_number(self.alliance_customer_number).first
      raise ArgumentError, "No importer found with Kewill customer number '#{self.alliance_customer_number}'." unless @importer
    end

    @importer
  end

  def query
    qry = <<-SQL
      SELECT products.id,
        #{has_option?(:use_unique_identifier) ? "products.unique_identifier" : cd_s(custom_defs[:prod_part_number].id)},
        products.name,
    SQL
    if has_option?(:allow_multiple_tariffs)
      qry += <<-SQL
        (SELECT GROUP_CONCAT(CONCAT_WS('***', hts_1, hts_2, hts_3) ORDER BY line_number SEPARATOR '*~*') 
         FROM tariff_records tar 
         WHERE tar.classification_id = classifications.id AND LENGTH(tar.hts_1) >= 8),
      SQL
    else
      qry += <<-SQL
        (SELECT CONCAT_WS('***', hts_1, hts_2, hts_3)
         FROM tariff_records tar 
         WHERE tar.classification_id = classifications.id AND LENGTH(tar.hts_1) >= 8 AND tar.line_number = 1),
      SQL
    end
    qry += <<-SQL 
        IF(LENGTH(#{cd_s custom_defs[:prod_country_of_origin].id, suppress_alias: true})=2,#{cd_s custom_defs[:prod_country_of_origin].id, suppress_alias: true},""),
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
        #{cd_s custom_defs[:prod_fda_accession_number]},
        #{cd_s custom_defs[:prod_301_exclusion_tariff]},
        (SELECT mid.system_code 
         FROM addresses mid 
           INNER JOIN product_factories pf ON pf.address_id = mid.id 
         WHERE pf.product_id = products.id 
         ORDER BY mid.created_at LIMIT 1),
        sys_id.code,
        #{cd_s custom_defs[:prod_cvd_case]},
        #{cd_s custom_defs[:prod_add_case]},
        #{cd_s custom_defs[:class_special_program_indicator]},
        #{cd_s custom_defs[:prod_lacey_component_of_article]},
        #{cd_s custom_defs[:prod_lacey_preparer_name]},
        #{cd_s custom_defs[:prod_lacey_preparer_email]},
        #{cd_s custom_defs[:prod_lacey_preparer_phone]},
        #{cd_s custom_defs[:prod_lacey_country_of_harvest]},
        #{cd_s custom_defs[:prod_lacey_quantity]},
        #{cd_s custom_defs[:prod_lacey_quantity_uom]},
        #{cd_s custom_defs[:prod_lacey_percent_recycled]},
        #{cd_s custom_defs[:prod_lacey_genus_1]},
        #{cd_s custom_defs[:prod_lacey_species_1]},
        #{cd_s custom_defs[:prod_lacey_genus_2]},
        #{cd_s custom_defs[:prod_lacey_species_2]}
      FROM products
        LEFT OUTER JOIN companies ON companies.id = products.importer_id
        LEFT OUTER JOIN system_identifiers sys_id ON sys_id.company_id = companies.id AND sys_id.system = 'Customs Management'
        INNER JOIN classifications on classifications.country_id = (SELECT id 
                                                                    FROM countries 
                                                                    WHERE iso_code = "US") AND classifications.product_id = products.id
    SQL

    # custom_where attr_reader method is defined in parent class
    if self.custom_where.blank?
      qry += "#{Product.need_sync_join_clause(sync_code)} WHERE #{Product.need_sync_where_clause()} "
    else 
      qry += "WHERE #{self.custom_where} "
    end
    
    qry += " AND (products.inactive IS NULL OR products.inactive = 0)"
    qry += " AND LENGTH(#{cd_s custom_defs[:prod_part_number].id, suppress_alias: true})>0" unless has_option?(:use_unique_identifier)
    qry += importer_id_query_clause

    unless has_option?(:allow_blank_tariffs)
      qry += <<-SQL
        AND LENGTH((SELECT GROUP_CONCAT(hts_1 ORDER BY line_number SEPARATOR '#{line_separator}') 
                    FROM tariff_records tar 
                    WHERE tar.classification_id = classifications.id AND LENGTH(tar.hts_1) >= 8)) >= 0
      SQL
    end
    
    if self.custom_where.blank?
      # Now that we're using XML, documents get really big, really quickly...so limit to X at a time per file
      qry += " LIMIT #{max_products_per_file}"
    end

    qry
  end

  def importer_id_query_clause
    if has_option?(:use_customer_numbers)
      qry = ActiveRecord::Base.sanitize_sql_array([" AND sys_id.code IN (?)", self.customer_numbers])
    else
      # If we've disabled the importer check, it means we're running potentially on a customer
      # specific system, which likely doesn't have an importer record linked to the product records
      if has_option?(:disable_importer_check)
        qry = ""
      else
        qry = " AND products.importer_id "
        if has_option?(:include_linked_importer_products)
          @child_importer_ids ||= importer.linked_companies.find_all {|c| c.importer? }.map &:id
          if @child_importer_ids.length > 0
            qry += " IN (?)"
            qry = ActiveRecord::Base.sanitize_sql_array([qry, @child_importer_ids])
          else
            # There were no child importers found, so don't add a clause that will return nothing.
            qry = " AND 1 = -1"
          end
        else
          qry += " = #{importer.id}"
        end
      end
    end

    qry
  end

  def tariffs product_data, row
    # We're concat'ing all the product's US tariffs into a single field in the SQL query and then splitting them out
    # here into individual classification fields. Since only the first line tariff fields (hts 1-3) are subject to
    # supplemental tariff handling/sorting, we separate them from the rest at the outset.
    
    first_line_tariffs, remaining_tariffs = Array.wrap(tariff_numbers(row).to_s.split(line_separator))
    first_line_tariffs = first_line_tariffs&.split("***")&.select{ |t| t.present? } || []
    remaining_tariffs = remaining_tariffs&.split("***")
                                         &.select{ |t| t.present? }
                                         &.map{ |t| TariffData.new(t, nil, nil, nil, nil) } || []

    all_tariffs = []
    # By starting at zero, any special tariff with a blank priority will get prioritized in front of the primary
    # tariff (as the first HTS 1 will have a priority of -0.01).  This is what we want.  
    # We're assuming that special tariffs in their default state (.ie without priorities)
    # should be sent to CMUS (aka Kewill) prior to the primary tariff numbers keyed on the part
    priority = 0.00
    first_line_tariffs.each_with_index do |t, index|
      td = TariffData.new(t, (priority -= 0.01), secondary_priority(t), (index == 0), false)

      # Check if any of the keyed tariffs are considered special tariffs, if so, use the priority
      # from the special tariff record so we can potentially reorder them below according to the 
      # special tariff xref's priority
      # We do this because we don't automatically add some special tariffs to the feed (like the MTB tariffs)
      # because they're not actually applicable to every part that has a matching tariff number.  For instance,
      # just because tariff 62401.12.5510 might have an MTB match, doesn't mean the actual part can carry an MTB
      # exemption.  This is because there's very specific rules for the exemptions that don't apply to every part
      # that can be classified with that number.

      # In other words, in order for MTB numbers to get sent to CMUS, they need to be keyed into the tariff fields.
      # If it is keyed, we need to make sure we utilize the special priority.
      # In the case of MTB tariffs, they need to be sent to CMUS prior to the primary tariff.
      
      special_tariff_priority = keyed_special_tariff_priority(country_of_origin(row), t)
      
      if !special_tariff_priority.nil?
        td.special_tariff = true
        # By default (with no actual priorities set), the special tariffs will appear before the standard
        # tariffs.  This is by design.  If special tariffs should appear AFTER the primary tariff, they should
        # have their priority set to a negative value.
        td.priority = special_tariff_priority
      end

      all_tariffs << td
    end

    exclusion_301_tariff = product_data.exclusion_301_tariff.to_s.strip.gsub(".", "")
    exclude_301_tariffs = exclusion_301_tariff.present?
    if exclusion_301_tariff.present?
      # We know the exclusion should always be the first tariff sent...so set its priority the highest
      all_tariffs << TariffData.new(exclusion_301_tariff, 1000, secondary_priority(exclusion_301_tariff), false, true)
    end

    # Find any special tariffs we should add into the tariff list, only utilize the tariff
    # numbers we know aren't already special tariffs
    all_tariffs.map { |t| t.special_tariff ? nil : t.tariff_number }.compact.each do |tariff_number|
      special_tariff_numbers(country_of_origin(row), tariff_number, exclude_301_tariffs).each do |special_tariff|
        # Don't add any special tariffs that may have already been keyed
        existing_special_tariff = all_tariffs.find {|existing_tariff| existing_tariff.tariff_number == special_tariff.special_hts_number }
        next unless existing_special_tariff.nil?

        all_tariffs << TariffData.new(special_tariff.special_hts_number, special_tariff.priority.to_f, secondary_priority(special_tariff.special_hts_number), false, true)
      end
    end
    
    all_tariffs.sort_by {|t| [t.priority, t.secondary_priority] }.reverse.concat remaining_tariffs
  end

  def special_tariff_numbers product_country_origin, hts_number, exclude_301_tariffs
    return [] if hts_number.blank? || has_option?(:disable_special_tariff_lookup)

    country_origin = (product_country_origin.presence || self.default_special_tariff_country_origin).to_s

    tariffs = special_tariff_hash.tariffs_for(country_origin, hts_number)
    tariffs.delete_if {|t| t.special_tariff_type.to_s.include?("301") } if exclude_301_tariffs

    tariffs
  end

  def special_tariff_hash
    @special_tariffs ||= SpecialTariffCrossReference.find_special_tariff_hash "US", true, reference_date: Time.zone.now.to_date
  end

  def keyed_special_tariff_priority product_country_origin, hts_number
    tariff = special_tariff_numbers_hash.tariffs_for(product_country_origin, hts_number)&.first
    priority = nil
    if tariff
      priority = tariff.priority.to_f
    end

    priority
  end

  def special_tariff_numbers_hash
    # Because these are tariffs that aren't automatically included, into the feed we pass false below to get ALL the special tariff numbers.
    # We also want to key the hash by the special number, not the standard number.
    @special_tariff_numbers_hash ||= SpecialTariffCrossReference.find_special_tariff_hash("US", false, reference_date: Time.zone.now.to_date, use_special_number_as_key: true)
  end
    
  def exclusion_301_tariff row
    row[22]
  end

  # The secondary priority is mostly just a failsafe to make sure that 301 tariffs are always prioritized above MTB
  # tariffs if their special tariff xref values are the same....This is primarily just codifying a default case.
  def secondary_priority tariff_number
    if is_mtb_tariff? tariff_number
      return 100
    elsif is_301_tariff? tariff_number
      return 200
    else
      return 0
    end
  end

  def is_mtb_tariff? tariff_number
    tariff_number.to_s.starts_with?("9902")
  end

  def is_301_tariff? tariff_number
    tariff_number.to_s.starts_with?("9903")
  end

  def validate_mid row
    # Validate the MID by making sure it's present in our MID table.  If it's not a valid MID, then don't send anything.

    # row 5 is the FDA MID.  I'm not entirely sure how that might be different from the standard MID, but we've been sending it
    # as the part's top level MID for years now if it's present, so continue to do this and then fall back to the standard MID
    # if it's not valid or missing

    # NOTE: the preprocess_row method blanks the FDA MID value unless the product is marked as being an FDA part.
    mid = nil
    if row[9].present?
      mid = manufacturer_id(row[9].strip)
    end

    if mid.blank? && row[23].present?
      mid = manufacturer_id(row[23].strip)
    end

    mid.presence || ""
  end

  def manufacturer_id mid
    @mids ||= Hash.new do |h, k|
      h[k] = ManufacturerId.where(mid: k).limit(1).pluck(:mid).first.to_s
    end

    @mids[mid]
  end

  def has_option? key
    options[key]
  end

  def add_options opts, *keys
    keys.each {|key| options[key] = opts[key].to_s.to_boolean }
  end

  def options
    @options ||= {}
  end

  def part_number row
    row[part_number_index]
  end

  def part_number_index
    0
  end

  def line_separator
    "*~*"
  end

  def tariff_numbers row
    row[2]
  end

  def country_of_origin row
    row[3]
  end

  def customer_number row
    row[24]
  end

  def supports_fda_data? 
    false
  end

end; end; end; end
