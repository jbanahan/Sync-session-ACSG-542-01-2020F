require 'open_chain/custom_handler/product_generator'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/vandegrift/kewill_product_generator_support'

module OpenChain; module CustomHandler; module Vandegrift; class KewillProductGenerator < OpenChain::CustomHandler::ProductGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::Vandegrift::KewillProductGeneratorSupport

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

  attr_reader :alliance_customer_number, :customer_numbers, :importer_system_code, :default_special_tariff_country_origin, :default_values,
              :effective_date_override, :expiration_date_override, :customer_number_override

  def initialize alliance_customer_number, opts = {}
    opts = opts.with_indifferent_access
    super(opts)

    # Combined with the use_inique_identifier flag, this allows us to run this on customer specific systems
    # (like DAS) where the products aren't linked to any importer - since the whole system is a single importer's system.
    add_options(opts, :include_linked_importer_products, :strip_leading_zeros, :use_unique_identifier, :disable_importer_check,
                :allow_blank_tariffs, :allow_multiple_tariffs, :disable_special_tariff_lookup, :allow_style_truncation,
                :suppress_fda_data, :use_updated_at_as_effective_date)
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
    if opts[:effective_date_override].present?
      @effective_date_override = Date.parse(opts[:effective_date_override])
    end

    if opts[:expiration_date_override].present?
      @expiration_date_override = Date.parse(opts[:expiration_date_override])
    end
    @customer_number_override = opts[:customer_number_override]
  end

  def custom_defs
    @cdefs ||= self.class.prep_custom_definitions [:prod_country_of_origin, :prod_part_number, :prod_fda_product, :prod_fda_product_code, :prod_fda_temperature, :prod_fda_uom,
                :prod_fda_country, :prod_fda_mid, :prod_fda_shipper_id, :prod_fda_description, :prod_fda_establishment_no, :prod_fda_container_length,
                :prod_fda_container_width, :prod_fda_container_height, :prod_fda_contact_name, :prod_fda_contact_phone, :prod_fda_affirmation_compliance,
                :prod_fda_affirmation_compliance_value, :prod_brand, :prod_301_exclusion_tariff, :prod_fda_accession_number, :prod_cvd_case, :prod_add_case,
                :class_special_program_indicator, :prod_lacey_component_of_article, :prod_lacey_genus_1, :prod_lacey_species_1, :prod_lacey_genus_2,
                :prod_lacey_species_2, :prod_lacey_country_of_harvest, :prod_lacey_quantity, :prod_lacey_quantity_uom, :prod_lacey_percent_recycled,
                :prod_lacey_preparer_name, :prod_lacey_preparer_email, :prod_lacey_preparer_phone]
    @cdefs
  end

  def sync_code
    'Alliance'
  end

  def sync_xml
    imp = importer unless has_option?(:disable_importer_check)
    val = super
    imp&.update!(last_alliance_product_push_at: Time.zone.now)
    val
  end

  def write_row_to_xml parent, _row_counter, row
    data = map_query_row_to_product_data(row)
    write_tariff_data_to_xml(parent, data)
  end

  def map_query_row_to_product_data row
    d = ProductData.new
    map_product_header_data(d, row)
    d.tariff_data = map_tariff_number_data(d, row)
    d.penalty_data = map_penalty_data(d, row)

    d
  end

  # This method provides the mapping for the base product header mapping that pretty much any
  # generator that extends this class almost certainly should be utilizing.
  def base_product_header_mapping d, row
    # The query should be pulling the Customs Management cust_no from the system identifiers table now, it's possible on some customer
    # systems that this won't be present, so just fall back to using the customer number set up from the constructor.
    d.customer_number = customer_number_value(row)
    d.part_number = part_number(row)
    d.part_number = d.part_number.to_s.gsub(/^0+/, "") if has_option?(:strip_leading_zeros)
    # The effective date / expiration date (aka Effective Date Start / End in Customs Management) is used as a means to version your
    # parts library in CM.  See comment on KewillProductGeneratorSupport#effective_date for full explanation
    d.effective_date = effective_date(effective_date_value: effective_date_value(row))
    d.expiration_date = expiration_date_value(row)
  end

  def customer_number_value row
    if self.customer_number_override.present?
      cust_no = self.customer_number_override
    else
      cust_no = customer_number(row).presence || self.alliance_customer_number
    end
    cust_no
  end

  def effective_date_value row
    if self.effective_date_override.present?
      results_date = self.effective_date_override
    else
      results_date = effective_date_from_results(row).presence || default_effective_date
    end

    results_date
  end

  def expiration_date_value row
    if self.expiration_date_override.present?
      exp_date = self.expiration_date_override
    else
      exp_date = expiration_date_from_results(row).presence || default_expiration_date
    end

    exp_date
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

    # All the PGA data should go on the primary tariff row and nothing else
    primary_tariff = find_primary_tariff(tariff_data)
    if primary_tariff
      primary_tariff.lacey_data = map_lacey_data(product, primary_tariff, row)
      primary_tariff.fda_data = map_fda_data(product, primary_tariff, row)
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

  def fda_data? row
    row[5] == "Y" || row[6].present?
  end

  def fda_affirmation_of_compliance? row
    row[18].present?
  end

  def map_fda_data _product, _tariff, row
    if fda_data? row
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

      if fda_affirmation_of_compliance?(row)
        f.affirmations_of_compliance << FdaAffirmationOfComplianceData.new(row[18], row[19])
      end

      # The Accession Number is simply another Affirmation of Compliance value with a specific Code of ACC
      if row[21].present?
        f.affirmations_of_compliance << FdaAffirmationOfComplianceData.new("ACC", row[21])
      end

      [f]
    else
      []
    end
  end

  def map_penalty_data _product, row
    penalties = []

    if row[25].present?
      penalties << PenaltyData.new("CVD", row[25])
    end

    if row[26].present?
      penalties << PenaltyData.new("ADA", row[26])
    end

    penalties
  end

  def map_lacey_data _product, _tariff, row
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
        c.scientific_names << ScientificName.new(row[36], row[37])
      end

      if row[38].present? && row[39].present?
        c.scientific_names << ScientificName.new(row[38], row[39])
      end

      lacey << l
    end

    lacey
  end

  def max_products_per_file
    500
  end

  # Override this method to return a value from the query result row to use as an effective date
  # if the extending generator wants to utilze CMUS part versioning
  def effective_date_from_results row
    date = nil
    if has_option?(:use_updated_at_as_effective_date)
      date = row[40].in_time_zone("America/New_York").to_date
    end
    date
  end

  def expiration_date_from_results _row
    nil
  end

  def importer
    if self.importer_system_code.present?
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
        #{cd_s custom_defs[:prod_lacey_species_2]},
        products.updated_at
      FROM products
        LEFT OUTER JOIN companies ON companies.id = products.importer_id
        LEFT OUTER JOIN system_identifiers sys_id ON sys_id.company_id = companies.id AND sys_id.system = 'Customs Management'
        INNER JOIN classifications on classifications.country_id = (SELECT id
                                                                    FROM countries
                                                                    WHERE iso_code = "US") AND classifications.product_id = products.id
    SQL

    # custom_where attr_reader method is defined in parent class
    if self.custom_where.blank?
      qry += "#{Product.need_sync_join_clause(sync_code)} WHERE #{Product.need_sync_where_clause} "
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

  def preprocess_row row, _opts = {}
    row.each do |column, val|
      # So, what we're doing here is attempting to transliterate any NON-ASCII data...
      # If that's not possible, we're using an ASCII bell character.

      # If the translated text then returns that we have a bell character (which really should never
      # occurr naturally in data), then we know we have an untranslatable char and we'll hard stop.

      if val.is_a? String
        translated = ActiveSupport::Inflector.transliterate(val, "\007")
        if translated =~ /\x07/
          raise "Untranslatable Non-ASCII character for Part Number '#{row[0]}' found at string index #{$LAST_MATCH_INFO.begin(0)} in product query column #{column}: '#{val}'." # rubocop:disable Layout/LineLength
        else
          # Strip newlines from everything, there's no scenario where a newline should be present in the file data
          row[column] = translated.gsub(/\r?\n/, " ")
        end
      end
    end

    super(row)
  # rubocop:disable Style/RescueStandardError
  rescue => e
    # Don't let a single product stop the rest of them from being sent.
    e.log_me
    nil
    # rubocop:enable Style/RescueStandardError
  end

  def importer_id_query_clause
    if has_option?(:use_customer_numbers)
      qry = ActiveRecord::Base.sanitize_sql_array([" AND sys_id.code IN (?)", self.customer_numbers])
    elsif has_option?(:disable_importer_check)
      qry = ""
    else
      # If we've disabled the importer check, it means we're running potentially on a customer
      # specific system, which likely doesn't have an importer record linked to the product records
      qry = " AND products.importer_id "
      if has_option?(:include_linked_importer_products)
        @child_importer_ids ||= importer.linked_companies.find_all(&:importer?).map(&:id)
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

    qry
  end

  def tariffs product_data, row
    # We're concat'ing all the product's US tariffs into a single field in the SQL query and then splitting them out
    # here into individual classification fields. Since only the first line tariff fields (hts 1-3) are subject to
    # supplemental tariff handling/sorting, we separate them from the rest at the outset.

    first_line_tariffs, remaining_tariffs = Array.wrap(tariff_numbers(row).to_s.split(line_separator))
    first_line_tariffs = first_line_tariffs&.split("***")&.select { |t| t.present? } || []
    remaining_tariffs = remaining_tariffs&.split("***")
                                         &.select { |t| t.present? }
                                         &.map { |t| TariffData.new(t) } || []

    all_tariffs = []
    # By starting at zero, any special tariff with a blank priority will get prioritized in front of the primary
    # tariff (as the first HTS 1 will have a priority of -0.01).  This is what we want.
    # We're assuming that special tariffs in their default state (.ie without priorities)
    # should be sent to CMUS (aka Kewill) prior to the primary tariff numbers keyed on the part
    priority = 0.00
    first_line_tariffs.each_with_index do |t, index|
      td = TariffData.make_tariff(t, (priority -= 0.01), secondary_priority(t), (index == 0), false)

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
      all_tariffs << TariffData.make_tariff(exclusion_301_tariff, 1000, secondary_priority(exclusion_301_tariff), false, true)
    end

    # Find any special tariffs we should add into the tariff list, only utilize the tariff
    # numbers we know aren't already special tariffs
    all_tariffs.map { |t| t.special_tariff ? nil : t.tariff_number }.compact.each do |tariff_number|
      special_tariff_numbers(country_of_origin(row), tariff_number, exclude_301_tariffs).each do |special_tariff|
        # Don't add any special tariffs that may have already been keyed
        existing_special_tariff = all_tariffs.find {|existing_tariff| existing_tariff.tariff_number == special_tariff.special_hts_number }
        next unless existing_special_tariff.nil?

        all_tariffs << TariffData.make_tariff(special_tariff.special_hts_number, special_tariff.priority.to_f,
                                              secondary_priority(special_tariff.special_hts_number), false, true)
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
    @special_tariff_hash ||= SpecialTariffCrossReference.find_special_tariff_hash "US", true, reference_date: Time.zone.now.to_date
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
    if mtb_tariff? tariff_number
      100
    elsif is_301_tariff? tariff_number
      200
    else
      0
    end
  end

  def mtb_tariff? tariff_number
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

  def has_option? key # rubocop:disable Naming/PredicateName
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
