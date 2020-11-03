# Finds associated HTS/COO/MID information based on the most recent entries for the
# given part_number
module OpenChain; class TariffFinder

  TariffPartData ||= Struct.new(:part_number, :country_origin_code, :mid, :hts_code)

  # Intialize with the country object that should be used to find the entries
  # and an array of Company objects for the importers whose entries should be used
  def initialize import_country_iso, importer_company_array
    @country = import_country_iso
    @importer_ids = importer_company_array.collect(&:id)
  end

  # find the most recent import by release_date that matches the style
  # and is optionally filtered by the given country of origin code
  #
  # returns an object with accessors for style, HTS, MID
  def by_style part_number, country_of_origin_code = nil
    cit = CommercialInvoiceTariff.joins(commercial_invoice_line: {commercial_invoice: :entry})
                                 .joins("INNER JOIN countries on entries.import_country_id = countries.id")
                                 .where("entries.importer_id IN (?)", @importer_ids)
                                 .where("commercial_invoice_lines.part_number = ?", part_number)
                                 .where("entries.release_date is not null")
                                 .where("commercial_invoice_tariffs.hts_code NOT LIKE '9802%'")
                                 .where("countries.iso_code = ?", @country)
    cit = cit.where("commercial_invoice_lines.country_origin_code = ?", country_of_origin_code) if country_of_origin_code.present?
    cit = cit.order("entries.release_date DESC, commercial_invoice_tariffs.hts_code ASC").first
    if cit
      cil = cit.commercial_invoice_line
      return TariffPartData.new(cil.part_number, cil.country_origin_code, cil.commercial_invoice.mfid, cit.hts_code)
    end
    nil
  end
end; end
