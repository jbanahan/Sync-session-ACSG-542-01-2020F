require 'open_chain/supplemental_tariff_support'
require 'open_chain/custom_handler/vandegrift/kewill_web_services_support'

# This module primarily just builds XML data structure from a given ProductData set of classes defined inside
# this module.

module OpenChain; module CustomHandler; module Vandegrift; module KewillProductGeneratorSupport
  extend ActiveSupport::Concern
  include OpenChain::CustomHandler::Vandegrift::KewillWebServicesSupport
  include OpenChain::SupplementalTariffSupport

  class ProductData
    attr_accessor :customer_number, :part_number, :effective_date, :expiration_date, :description, :country_of_origin, :mid, :product_line, :exclusion_301_tariff,
                  # TSCA Values are A = Article, C = Complies, N = Not Subject
                  :tsca_certification, :tariff_data, :penalty_data
  end

  # This is CVD / ADD data
  class PenaltyData
    # penalty_type should be CVD or ADA (for ADD cases)
    attr_accessor :penalty_type, :case_number

    def initialize type, case_number
      @penalty_type = type
      @case_number = case_number
    end
  end

  class TariffData
    attr_accessor :tariff_number, :priority, :secondary_priority, :primary_tariff, :special_tariff, :spi, :spi2, :description, :description_date,
                  :fda_flag, :dot_flag, :fws_flag, :lacey_flag, :fcc_flag,
                  :fda_data, :lacey_data, :dot_data, :fish_wildlife_data, :epa_data

    def initialize tariff_number = nil
      @tariff_number = tariff_number
    end

    def self.make_tariff tariff_number, priority, secondary_priority, primary_tariff, special_tariff
      t = self.new tariff_number
      t.priority = priority
      t.secondary_priority = secondary_priority
      t.primary_tariff = primary_tariff
      t.special_tariff = special_tariff

      t
    end
  end

  class DotData
    attr_accessor :nhtsa_program, :box_number
  end

  class FdaData
    attr_accessor :product_code, :uom, :country_production, :mid, :shipper_id, :description, :establishment_number, :container_dimension_1,
                  :container_dimension_2, :container_dimension_3, :contact_name, :contact_phone, :cargo_storage_status,
                  :affirmations_of_compliance
  end

  class FdaAffirmationOfComplianceData
    attr_accessor :code, :qualifier

    def initialize code, qualifier = nil
      @code = code
      @qualifier = qualifier
    end
  end

  class LaceyData
    attr_accessor :preparer_name, :preparer_email, :preparer_phone, :components
  end

  class LaceyComponentData
    attr_accessor :component_of_article, :country_of_harvest, :quantity, :quantity_uom, :percent_recycled, :common_name_general, :scientific_names
  end

  class ScientificName
    attr_accessor :genus, :species

    def initialize genus, species
      @genus = genus
      @species = species
    end
  end

  class FishWildlifeData
    attr_accessor :common_name_general, :country_where_born, :foreign_value, :description_code, :source_description, :source_code, :scientific_name
  end

  class EpaData
    # epa_code - one of EP1-8
    # epa_program_code - TS1 = TSCA, PST = Pesticides, VNE = Vehicles / Engines, ODS = Ozone Depleting Substance
    # If positive certification is true, this will result in a EP4 TSCA declaration (Positive Certification) being added to the part
    # If postitive certification is false, this will result in an EP5 TSCA declaration (Negative Certification) being added to the part
    # Positive Certification appears to only be applicable for TSCA (TS1) and Ozone Depleting Substance (ODS)
    attr_accessor :epa_code, :epa_program_code, :positive_certification
  end

  def ftp_credentials
    ecs_connect_vfitrack_net('kewill_edi/to_kewill')
  end

  def write_tariff_data_to_xml parent, data
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
        add_tariff_data(tariff_class, tariff_data)
        append_defaults(tariff_class, "CatTariffClass")

        if Array.wrap(tariff_data.fda_data).length > 0
          fda_es_list = add_element(tariff_class, "CatFdaEsList")
          Array.wrap(tariff_data.fda_data).each_with_index do |fda_data, fda_index|
            fda_seq = fda_index + 1

            fda = add_element(fda_es_list, "CatFdaEs")
            add_kewill_keys fda, data

            # This is the CatTariffClass "key"...whoever designed this XML was dumb.
            add_element(fda, "seqNo", tariff_seq)
            add_element(fda, "fdaSeqNo", fda_seq)
            add_fda_data(fda, fda_data)

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
              end
            end
          end
        end

        if _has_pga_data?(tariff_data)
          pg_es_list = add_element(tariff_class, "CatPgEsList")

          product_seq_number = 1
          Array.wrap(tariff_data.lacey_data).each_with_index do |lacey, lacey_index|
            pg_seq_number = lacey_index + 1

            pg = add_element(pg_es_list, "CatPgEs")
            add_pg_es_data(pg, data, tariff_seq, pg_seq_number, "AL1", pg_agency_code: "APH", pg_program_code: "APL")

            aphis_es = add_element(pg, "CatPgAphisEs")
            add_pg_es_data(aphis_es, data, tariff_seq, pg_seq_number, "AL1", pg_agency_code: "APH", pg_program_code: "APL")
            add_element(aphis_es, "productSeqNbr", product_seq_number)

            add_lacey_data(aphis_es, lacey)

            if Array.wrap(lacey.components).length > 0
              pg_components_list = add_element(aphis_es, "CatPgAphisEsComponentsList")

              Array.wrap(lacey.components).each_with_index do |component, component_index|
                component_seq_number = component_index + 1

                comp = add_element(pg_components_list, "CatPgAphisEsComponents")
                add_pg_es_data(comp, data, tariff_seq, pg_seq_number, "AL1")
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
                    add_pg_es_data(science, data, tariff_seq, pg_seq_number, "AL1")
                    add_element(science, "productSeqNbr", product_seq_number)
                    add_element(science, "componentSeqNbr", component_seq_number)
                    add_element(science, "scientificSeqNbr", scientific_seq_no)

                    add_lacey_scientific_name(science, scientific_name)
                  end
                end
              end
            end
          end
        end

        product_seq_number = 1
        Array.wrap(tariff_data.fish_wildlife_data).each_with_index do |fws, fws_index|
          pg_seq_number = fws_index + 1

          pg = add_element(pg_es_list, "CatPgEs")
          add_pg_es_data(pg, data, tariff_seq, pg_seq_number, "FW2", pg_agency_code: "FWS", pg_program_code: "FWS", agency_processing_code: "EDS")

          fw_es = add_element(pg, "CatPgFwsEs")
          add_pg_es_data(fw_es, data, tariff_seq, pg_seq_number, "FW2", pg_agency_code: "FWS", pg_program_code: "FWS")
          add_fish_wildlife_data(fw_es, fws)
        end

        product_seq_number = 1
        Array.wrap(tariff_data.dot_data).each_with_index do |dot, dot_index|
          pg_seq_number = dot_index + 1

          pg = add_element(pg_es_list, "CatPgEs")
          add_pg_es_data(pg, data, tariff_seq, pg_seq_number, "DT1", pg_agency_code: "NHT", pg_program_code: dot.nhtsa_program)
          nhtsa_es = add_element(pg, "CatNhtsaEs")
          add_pg_es_data(nhtsa_es, data, tariff_seq, pg_seq_number, "DT1", pg_agency_code: "NHT")
          add_nhtsa_data(nhtsa_es, dot)
        end

        product_seq_number = 1
        Array.wrap(tariff_data.epa_data).each_with_index do |epa, epa_index|
          pg_seq_number = epa_index + 1

          pg = add_element(pg_es_list, "CatPgEs")
          add_pg_es_data(pg, data, tariff_seq, pg_seq_number, epa.epa_code, pg_agency_code: "EPA", pg_program_code: epa.epa_program_code)
          epa_es = add_element(pg, "CatPgEpaEs")
          add_pg_es_data(epa_es, data, tariff_seq, pg_seq_number, epa.epa_code)
          add_epa_data(epa_es, epa)
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

      tariff_class_aux_list = nil
      Array.wrap(data.tariff_data).each_with_index do |tariff, tariff_index|
        next if tariff.description.blank?

        tariff_class_aux_list ||= add_element(p, "CatTariffClassAuxList")

        tariff_seq = tariff_index + 1
        tariff_class_aux = add_element(tariff_class_aux_list, "CatTariffClassAux")
        add_kewill_keys(tariff_class_aux, data)
        add_element(tariff_class_aux, "seqNo", tariff_seq)
        add_tariff_aux_data(tariff_class_aux, tariff)
        append_defaults(tariff_class_aux, "CatTariffClassAux")
      end
    end

    nil
  end

  def add_part_data part, data
    write_data(part, "styleNo", data.part_number, 40)
    write_data(part, "descr", data.description.to_s.upcase, 40)
    write_data(part, "countryOrigin", data.country_of_origin, 2)
    write_data(part, "manufacturerId", data.mid, 15)
    write_data(part, "productLine", data.product_line, 30)
    write_data(part, "tscaCert", data.tsca_certification, 1)
    write_data(part, "dateExpiration", _date_format(data.expiration_date), 8, error_on_trim: true)

    nil
  end

  def add_tariff_data tariff_class, tariff_data
    # Since we're allowing blank tariffs, just take part of the join condition for 8 char tariffs and recreate it here, dropping
    # anything that's less than 8 chars (.ie not a good tariff)
    write_data(tariff_class, "tariffNo", (tariff_data.tariff_number.to_s.length >= 8 ? tariff_data.tariff_number : ""), 10, error_on_trim: true)
    write_data(tariff_class, "spiPrimary", tariff_data.spi, 2) if tariff_data.spi.present?
    write_data(tariff_class, "spiSecondary", tariff_data.spi2, 1) if tariff_data.spi2.present?
    # Don't send the flags if they're nil, otherwise send Y/N
    write_data(tariff_class, "dotOgaFlag", (tariff_data.dot_flag ? "Y" : "N"), 1) unless tariff_data.dot_flag.nil?
    write_data(tariff_class, "fdaOgaFlag", (tariff_data.fda_flag ? "Y" : "N"), 1) unless tariff_data.fda_flag.nil?
    write_data(tariff_class, "fwsOgaFlag", (tariff_data.fws_flag ? "Y" : "N"), 1) unless tariff_data.fws_flag.nil?
    write_data(tariff_class, "lcyPgaFlag", (tariff_data.lacey_flag ? "Y" : "N"), 1) unless tariff_data.lacey_flag.nil?
    write_data(tariff_class, "fccOgaFlag", (tariff_data.fcc_flag ? "Y" : "N"), 1) unless tariff_data.fcc_flag.nil?
    nil
  end

  def add_tariff_aux_data parent, tariff_data
    # For some mindboggling reason, you need to send a create date for the description to CMUS
    if tariff_data.description.present? && tariff_data.description_date.present?
      write_data(parent, "commercialDesc", tariff_data.description, 70)
      # This date is (for some reason), an actual DateTime XML element (rather than an int like all the others) in the
      # schema
      write_data(parent, "createdDate", _date_format(tariff_data.description_date, format: "%Y-%m-%d"), 10)
    end
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
    write_data(parent, "commonNameGeneral", component.common_name_general, 30)

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
    nil
  end

  def add_nhtsa_data parent, nhtsa_data
    write_data(parent, "boxNo", nhtsa_data.box_number, 2)
    nil
  end

  def add_epa_data parent, epa_data
    if !epa_data.positive_certification.nil?
      write_data(parent, "declarationCd", (epa_data.positive_certification ? "EP4" : "EP5"), 4)
      document_code = case epa_data.epa_program_code.to_s.upcase
                      when "ODS"
                        "942"
                      when "TS1"
                          "944"
                      end
      write_data(parent, "documentIdCd", document_code, 7) if document_code.present?
    end

    nil
  end

  def add_fish_wildlife_data parent, fish_wildlife_data
    write_data(parent, "commonNameGeneral", fish_wildlife_data.common_name_general, 30)
    write_data(parent, "countryWhereBorn", fish_wildlife_data.country_where_born, 2)
    write_data(parent, "pgaLineValueForeign", _implied_decimal_format(fish_wildlife_data.foreign_value), 12)
    write_data(parent, "fwsDescriptionCd", fish_wildlife_data.description_code, 7)
    write_data(parent, "sourceCharDesc", fish_wildlife_data.source_description, 57)
    write_data(parent, "sourceCd", fish_wildlife_data.source_code, 57)
    write_data(parent, "scientificGenusName1", fish_wildlife_data&.scientific_name&.genus, 22)
    write_data(parent, "scientificSpeciesName1", fish_wildlife_data&.scientific_name&.species, 22)
  end

  def add_pg_es_data parent, product_data, tariff_seq_no, pg_seq_number, pg_code, pg_agency_code: nil, pg_program_code: nil, agency_processing_code: nil
    add_kewill_keys parent, product_data
    add_element(parent, "seqNo", tariff_seq_no)
    add_element(parent, "pgCd", pg_code)
    add_element(parent, "pgAgencyCd", pg_agency_code) if pg_agency_code.present?
    add_element(parent, "agencyProcessingCd", agency_processing_code) if agency_processing_code.present?
    add_element(parent, "pgProgramCd", pg_program_code) if pg_program_code.present?
    add_element(parent, "pgSeqNbr", pg_seq_number)
  end

  def xml_document_and_root_element
    doc, kc_data = create_document category: "Parts", subAction: "CreateUpdate"
    parts = add_element(kc_data, "parts")
    [doc, parts]
  end

  def add_kewill_keys parent, data, include_style: true, allow_style_truncation: nil
    if allow_style_truncation.nil? && self.respond_to?(:has_option?)
      allow_style_truncation = has_option?(:allow_style_truncation)
    else
      allow_style_truncation = allow_style_truncation.nil? ? false : allow_style_truncation
    end

    write_data(parent, "custNo", data.customer_number, 10, error_on_trim: true)
    write_data(parent, "partNo", data.part_number, 40, error_on_trim: !allow_style_truncation)
    write_data(parent, "styleNo", data.part_number, 40, error_on_trim: !allow_style_truncation) if include_style
    write_data(parent, "dateEffective", _date_format(data.effective_date), 8, error_on_trim: true)
  end

  def write_data(parent, element_name, data, max_length, allow_blank: false, error_on_trim: false)
    if data && data.to_s.length > max_length
      # There's a few values we never want to truncate, hence the check here.  Those are mostly only just primary key fields in Kewill
      # that we never want to truncate.
      raise "#{element_name} cannot be over #{max_length} characters.  It was '#{data}'." if error_on_trim

      data = data.to_s[0, max_length]
    end

    add_element parent, element_name, data, allow_blank: allow_blank
  end

  def append_defaults parent, level
    defaults = self.default_values[level]
    return if defaults.blank?

    defaults.each_pair do |name, value|
      add_element(parent, name, value)
    end
  end

  def default_values
    {}
  end

  #
  # The Effective Date field in CMUS is how that system handles versioning of the
  # product data.  Every time you send a new part file, the system will
  # evaluate the effective date in it and will determine if that date occurs after
  # the newest part in the system for the customer.  If it is newer, CMUS will set
  # the older part's expiration_date to the current date, retaining all the data.
  #
  # When the part data is referenced on the entry, the effective date is used to determine
  # which part data to utilize (I believe the import date is used as the reference value
  # when determining which part data to use).
  #
  # Over time, you'll have several versions of the part data.  This allows for history
  # tracking, and CMUS also provides a purge function that can be utilized based off
  # of the last time the part record was referenced.  So you can automatically purge
  # parts that might have not been used for over 5 years.
  #
  # For now, we're going to stick with using a hardcoded date value of 2014-01-01
  # as we have done for quite some time (since we had no idea this feature existed)
  # which effectively removes all versioning.
  #
  # But if we want to start using the feature, we can just feed in a product record
  # to utilize the updated_at value or a value from a query to use as the effective date.
  #
  def effective_date product: nil, effective_date_value: nil
    effective_date = nil
    if product
      effective_date = product&.updated_at
    elsif effective_date_value
      effective_date = effective_date_value
    end

    if effective_date
      # If we're dealing w/ a date with a time component, shift it to
      # the current time in Eastern time zone (since that's what CMUS is set to)
      if effective_date.respond_to?(:in_time_zone)
        effective_date = effective_date.in_time_zone("America/New_York").to_date
      end
    else
      effective_date = default_effective_date
    end

    effective_date
  end

  def default_effective_date
    @default_effective_date ||= Date.new(2014, 1, 1)
  end

  def default_expiration_date
    @default_expiration_date ||= Date.new(2099, 12, 31)
  end
  alias expiration_date default_expiration_date

  def _has_pga_data? tariff_data
    Array.wrap(tariff_data.lacey_data).length > 0 ||
      Array.wrap(tariff_data.dot_data).length > 0 ||
      Array.wrap(tariff_data.fish_wildlife_data).length > 0 ||
      Array.wrap(tariff_data.epa_data).length > 0
  end

  def _date_format date, format: "%Y%m%d"
    date ? date.strftime(format) : nil
  end

  def _implied_decimal_format value, decimal_places: 2
    return nil if value.nil?

    value.round(decimal_places).to_s.gsub(".", "")
  end

end; end; end; end
