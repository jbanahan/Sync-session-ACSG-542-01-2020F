require 'open_chain/custom_handler/vandegrift/active_record_kewill_product_generator_support'
require 'open_chain/custom_handler/target/target_custom_definition_support'

module OpenChain; module CustomHandler; module Target; class TargetCustomsManagementProductGenerator
  include OpenChain::CustomHandler::Vandegrift::ActiveRecordKewillProductGeneratorSupport
  include OpenChain::CustomHandler::Target::TargetCustomDefinitionSupport

  def self.run_schedulable opts = {}
    g = self.new opts
    g.sync_xml(g.importer)
    nil
  end

  def initialize opts = {}
    @output_customer_number = opts&.[]("output_customer_number")
    @importer_customer_number = opts&.[]("importer_customer_number")
  end

  def importer
    Company.with_customs_management_number(importer_customer_number).first
  end

  def build_data product
    d = build_product_data(product)
    d.tariff_data = []
    d.penalty_data = build_penalty_data(product)

    non_primary_hts_numbers = Set.new
    us_tariffs(product).each do |tariff|
      tariffs = build_product_tariffs(product, tariff)
      # All of the PGA data goes on the primary tariff
      primary = nil
      # If we have multiple of the same non-primary tariffs, strip them out..
      # Target sends 9903s for every tariff line (for some reason)...when we only need to add it for
      # one line when sending to Kewill.
      retained_tariffs = []
      tariffs.each do |t|
        if t.primary_tariff
          primary = t
        else
          next if non_primary_hts_numbers.include?(t.tariff_number)

          non_primary_hts_numbers << t.tariff_number
        end

        retained_tariffs << t
      end

      d.tariff_data.push(*retained_tariffs)

      if primary
        primary.fda_data = build_fda_data(product, tariff)
        primary.dot_data = build_dot_data(product, tariff)
        primary.lacey_data = build_lacey_data(product, tariff)
        primary.fish_wildlife_data = build_fish_wildlife_data(product, tariff)
        primary.epa_data = build_epa_data(product, tariff)
      end
    end

    d
  end

  def build_product_data product
    d = ProductData.new
    d.customer_number = output_customer_number
    d.part_number = product.unique_identifier
    d.effective_date = effective_date
    d.expiration_date = expiration_date
    d.description = product.name
    d.tsca_certification = "C" if product.custom_value(cdefs[:prod_tsca]) == true
    country = primary_country_origin(product)
    d.country_of_origin = country if country.present?

    d
  end

  def build_penalty_data product
    penalties = []
    us_tariffs(product).each do |tariff|
      add_case = tariff.custom_value(cdefs[:tar_add_case])
      if add_case.present?
        penalties << PenaltyData.new("ADA", add_case)
      end
      cvd_case = tariff.custom_value(cdefs[:tar_cvd_case])
      if cvd_case.present?
        penalties << PenaltyData.new("CVD", cvd_case)
      end
    end
    penalties
  end

  def build_product_tariffs _product, tariff_record
    tariffs = []
    if tariff_record.hts_1.present?
      tariffs << TariffData.new(tariff_record.hts_1)
    end

    if tariff_record.hts_2.present?
      tariffs << TariffData.new(tariff_record.hts_2)
    end

    if tariff_record.hts_3.present?
      tariffs << TariffData.new(tariff_record.hts_3)
    end

    # Find the first non-supplemental tariff and mark it as the primary
    primary_tariff = tariffs.find { |t| !supplemental_tariff?(t.tariff_number) }
    if primary_tariff
      primary_tariff.primary_tariff = true

      primary_tariff.spi = tariff_record.custom_value(cdefs[:tar_spi_primary])
      primary_tariff.spi2 = tariff_record.custom_value(cdefs[:tar_xvv])
      primary_tariff.description = tariff_record.custom_value(cdefs[:tar_component_description])
      # This is kind of bizarre but for some reason the descriptoin in CMUS requires a date to be
      # associated with it...so we're going to use the create date for the actual custom value record
      desc_date = tariff_record.find_custom_value(cdefs[:tar_component_description])&.created_at
      if desc_date
        primary_tariff.description_date = desc_date.in_time_zone("America/New_York")
      end

      primary_tariff.fda_flag = tariff_record.custom_value(cdefs[:tar_fda_flag])
      primary_tariff.dot_flag = tariff_record.custom_value(cdefs[:tar_dot_flag])
      primary_tariff.lacey_flag = tariff_record.custom_value(cdefs[:tar_lacey_flag])
      primary_tariff.fws_flag = tariff_record.custom_value(cdefs[:tar_fws_flag])
    end

    tariffs
  end

  def build_fda_data _product, tariff_record
    fda = nil
    if tariff_record.custom_value(cdefs[:tar_fda_product_code]).present? || tariff_record.custom_value(cdefs[:tar_fda_affirmation_code_1]).present?
      fda = FdaData.new
      fda.product_code = tariff_record.custom_value(cdefs[:tar_fda_product_code])
      fda.cargo_storage_status = tariff_record.custom_value(cdefs[:tar_fda_cargo_status])
      fda.affirmations_of_compliance = []

      (1..7).each do |x|
        # An Affirmation of Compliance code is always present if needed, the qualifier is optional
        code = tariff_record.custom_value(cdefs["tar_fda_affirmation_code_#{x}".to_sym])
        next if code.blank?

        fda.affirmations_of_compliance << FdaAffirmationOfComplianceData.new(code, tariff_record.custom_value(cdefs["tar_fda_affirmation_qualifier_#{x}".to_sym]))
      end
    end

    fda.nil? ? [] : [fda]
  end

  def build_dot_data _product, tariff_record
    dot = nil

    if tariff_record.custom_value(cdefs[:tar_dot_box_number]).present?
      dot = DotData.new
      dot.nhtsa_program = tariff_record.custom_value(cdefs[:tar_dot_program])
      dot.box_number = tariff_record.custom_value(cdefs[:tar_dot_box_number])
    end

    dot.nil? ? [] : [dot]
  end

  def build_lacey_data _product, tariff_record
    lacey_records = []
    (1..10).each do |x|
      fields = {}
      fields["tar_lacey_common_name_#{x}"] = tariff_record.custom_value(cdefs["tar_lacey_common_name_#{x}".to_sym])
      fields["tar_lacey_genus_#{x}"] = tariff_record.custom_value(cdefs["tar_lacey_genus_#{x}".to_sym])
      fields["tar_lacey_species_#{x}"] = tariff_record.custom_value(cdefs["tar_lacey_species_#{x}".to_sym])
      fields["tar_lacey_country_#{x}"] = tariff_record.custom_value(cdefs["tar_lacey_country_#{x}".to_sym])
      fields["tar_lacey_quantity_#{x}"] = tariff_record.custom_value(cdefs["tar_lacey_quantity_#{x}".to_sym])
      fields["tar_lacey_uom_#{x}"] = tariff_record.custom_value(cdefs["tar_lacey_uom_#{x}".to_sym])
      fields["tar_lacey_recycled_#{x}"] = tariff_record.custom_value(cdefs["tar_lacey_recycled_#{x}".to_sym])

      next if fields.values.all?(&:blank?)

      lacey = LaceyComponentData.new
      lacey.country_of_harvest = fields["tar_lacey_country_#{x}"]
      lacey.quantity = fields["tar_lacey_quantity_#{x}"]
      lacey.quantity_uom = fields["tar_lacey_uom_#{x}"]
      lacey.percent_recycled = fields["tar_lacey_recycled_#{x}"]
      lacey.common_name_general = fields["tar_lacey_common_name_#{x}"]

      if fields["tar_lacey_genus_#{x}"].present? && fields["tar_lacey_species_#{x}"].present?
        lacey.scientific_names = [ScientificName.new(fields["tar_lacey_genus_#{x}"], fields["tar_lacey_species_#{x}"])]
      end

      lacey_records << lacey
    end

    lacey = []
    if lacey_records.length > 0
      d = LaceyData.new
      d.components = lacey_records
      lacey << d
    end

    lacey
  end

  def build_fish_wildlife_data _product, tariff_record
    fws_records = []
    (1..5).each do |x|
      fields = {}
      fields["tar_fws_genus_#{x}"] = tariff_record.custom_value(cdefs["tar_fws_genus_#{x}".to_sym])
      fields["tar_fws_country_origin_#{x}"] = tariff_record.custom_value(cdefs["tar_fws_country_origin_#{x}".to_sym])
      fields["tar_fws_species_#{x}"] = tariff_record.custom_value(cdefs["tar_fws_species_#{x}".to_sym])
      fields["tar_fws_general_name_#{x}"] = tariff_record.custom_value(cdefs["tar_fws_general_name_#{x}".to_sym])
      fields["tar_fws_cost_#{x}"] = tariff_record.custom_value(cdefs["tar_fws_cost_#{x}".to_sym])
      fields["tar_fws_description_#{x}"] = tariff_record.custom_value(cdefs["tar_fws_description_#{x}".to_sym])
      fields["tar_fws_description_code_#{x}"] = tariff_record.custom_value(cdefs["tar_fws_description_code_#{x}".to_sym])
      fields["tar_fws_source_code_#{x}"] = tariff_record.custom_value(cdefs["tar_fws_source_code_#{x}".to_sym])

      next if fields.values.all?(&:blank?)

      fws = FishWildlifeData.new
      fws.common_name_general = fields["tar_fws_general_name_#{x}"]
      fws.country_where_born = fields["tar_fws_country_origin_#{x}"]
      fws.foreign_value = fields["tar_fws_cost_#{x}"]
      fws.description_code = fields["tar_fws_description_code_#{x}"]
      fws.source_description = fields["tar_fws_description_#{x}"]
      fws.source_code = fields["tar_fws_source_code_#{x}"]

      if fields["tar_fws_genus_#{x}"].present? && fields["tar_fws_genus_#{x}"].present?
        fws.scientific_name = ScientificName.new(fields["tar_fws_genus_#{x}"], fields["tar_fws_species_#{x}"])
      end

      fws_records << fws
    end

    fws_records
  end

  def build_epa_data product, _tariff_record
    # The EPA data we're going to look for is the TSCA flag. At which point we can add EPA data to the record
    epa_records = []
    if product.custom_value(cdefs[:prod_tsca])
      e = EpaData.new
      # EP7 = TSCA May be required
      e.epa_code = "EP7"
      # TS1 = TSCA program code
      e.epa_program_code = "TS1"
      # If the data from target indicates that the TSCA POSITIVE document is required, then we can add the
      # document certification to the transfer to CM
      if product.custom_value(cdefs[:prod_required_documents]).to_s.upcase.include? "TSCA POSITIVE"
        e.positive_certification = true
      end

      epa_records << e
    end
    epa_records
  end

  def importer_customer_number
    @importer_customer_number.presence || "TARGEN"
  end

  def output_customer_number
    @output_customer_number.presence || "TARGEN"
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:prod_aphis, :prod_usda, :prod_epa, :prod_cps, :prod_tsca, :prod_required_documents,
        :tar_country_of_origin, :tar_spi_primary, :tar_xvv, :tar_component_description,
        :tar_cvd_case, :tar_add_case, :tar_dot_flag, :tar_dot_program, :tar_dot_box_number, :tar_fda_flag, :tar_fda_product_code,
        :tar_fda_cargo_status, :tar_fda_food, :tar_fda_affirmation_code_1, :tar_fda_affirmation_code_2, :tar_fda_affirmation_code_3,
        :tar_fda_affirmation_code_4, :tar_fda_affirmation_code_5, :tar_fda_affirmation_code_6, :tar_fda_affirmation_code_7,
        :tar_fda_affirmation_qualifier_1, :tar_fda_affirmation_qualifier_2, :tar_fda_affirmation_qualifier_3, :tar_fda_affirmation_qualifier_4,
        :tar_fda_affirmation_qualifier_5, :tar_fda_affirmation_qualifier_6, :tar_fda_affirmation_qualifier_7, :tar_lacey_flag,
        :tar_lacey_common_name_1, :tar_lacey_common_name_2, :tar_lacey_common_name_3, :tar_lacey_common_name_4, :tar_lacey_common_name_5, :tar_lacey_common_name_6,
        :tar_lacey_common_name_7, :tar_lacey_common_name_8, :tar_lacey_common_name_9, :tar_lacey_common_name_10, :tar_lacey_genus_1,
        :tar_lacey_genus_2, :tar_lacey_genus_3, :tar_lacey_genus_4, :tar_lacey_genus_5, :tar_lacey_genus_6, :tar_lacey_genus_7,
        :tar_lacey_genus_8, :tar_lacey_genus_9, :tar_lacey_genus_10, :tar_lacey_species_1, :tar_lacey_species_2, :tar_lacey_species_3,
        :tar_lacey_species_4, :tar_lacey_species_5, :tar_lacey_species_6, :tar_lacey_species_7, :tar_lacey_species_8, :tar_lacey_species_9,
        :tar_lacey_species_10, :tar_lacey_country_1, :tar_lacey_country_2, :tar_lacey_country_3, :tar_lacey_country_4, :tar_lacey_country_5,
        :tar_lacey_country_6, :tar_lacey_country_7, :tar_lacey_country_8, :tar_lacey_country_9, :tar_lacey_country_10, :tar_lacey_quantity_1,
        :tar_lacey_quantity_2, :tar_lacey_quantity_3, :tar_lacey_quantity_4, :tar_lacey_quantity_5, :tar_lacey_quantity_6, :tar_lacey_quantity_7,
        :tar_lacey_quantity_8, :tar_lacey_quantity_9, :tar_lacey_quantity_10, :tar_lacey_uom_1, :tar_lacey_uom_2, :tar_lacey_uom_3, :tar_lacey_uom_4,
        :tar_lacey_uom_5, :tar_lacey_uom_6, :tar_lacey_uom_7, :tar_lacey_uom_8, :tar_lacey_uom_9, :tar_lacey_uom_10, :tar_lacey_recycled_1, :tar_lacey_recycled_2,
        :tar_lacey_recycled_3, :tar_lacey_recycled_4, :tar_lacey_recycled_5, :tar_lacey_recycled_6, :tar_lacey_recycled_7, :tar_lacey_recycled_8,
        :tar_lacey_recycled_9, :tar_lacey_recycled_10, :tar_fws_flag, :tar_fws_genus_1, :tar_fws_genus_2, :tar_fws_genus_3, :tar_fws_genus_4,
        :tar_fws_genus_5, :tar_fws_species_1, :tar_fws_species_2, :tar_fws_species_3, :tar_fws_species_4, :tar_fws_species_5, :tar_fws_general_name_1, :tar_fws_general_name_2,
        :tar_fws_general_name_3, :tar_fws_general_name_4, :tar_fws_general_name_5, :tar_fws_country_origin_1, :tar_fws_country_origin_2,
        :tar_fws_country_origin_3, :tar_fws_country_origin_4, :tar_fws_country_origin_5, :tar_fws_cost_1, :tar_fws_cost_2, :tar_fws_cost_3,
        :tar_fws_cost_4, :tar_fws_cost_5, :tar_fws_description_1, :tar_fws_description_2, :tar_fws_description_3, :tar_fws_description_4, :tar_fws_description_5,
        :tar_fws_description_code_1, :tar_fws_description_code_2, :tar_fws_description_code_3, :tar_fws_description_code_4, :tar_fws_description_code_5,
        :tar_fws_source_code_1, :tar_fws_source_code_2, :tar_fws_source_code_3, :tar_fws_source_code_4, :tar_fws_source_code_5])
  end

  def us_tariffs product
    classification = product.classifications.find { |c| c.country_id == us.id }
    return [] if classification.nil?

    classification.tariff_records.to_a
  end

  def us
    @country ||= Country.where(iso_code: "US").first
    raise "Failed to find US country" if @country.nil?

    @country
  end

  def primary_country_origin product
    # Figure out which country was used the most as the country of origin...
    # Use that as the COO for the header
    countries = Hash.new(0)
    us_tariffs(product).each do |t|
      coo = t.custom_value(cdefs[:tar_country_of_origin])
      next if coo.blank?

      countries[coo] += 1
    end

    max = nil
    country = nil
    countries.each_pair do |k, v|
      if max.nil? || v > max
        country = k
        max = v
      end
    end

    country
  end

end; end; end; end
