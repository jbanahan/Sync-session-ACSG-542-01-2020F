# Finds associated HTS/COO/MID information based on the most recent entries for the 
# given part_number
module OpenChain; class TariffFinder
  # Intialize with the country object that should be used to find the entries 
  # and an array of Company objects for the importers whose entries should be used
  def initialize import_country, importer_company_array
    @country_id = import_country.id
    @importer_ids = importer_company_array.collect {|imp| imp.id}
  end
  
  # find the most recent import by release_date that matches the style
  # and is optionally filtered by the given country of origin code
  # 
  # returns an object with accessors for style, HTS, MID
  def find_by_style part_number, country_of_origin_code=nil
    s = Struct.new(:part_number,:country_origin_code,:mid,:hts_code)
	  cit = CommercialInvoiceTariff.joins(:commercial_invoice_line=>{:commercial_invoice=>:entry}).
      where("entries.importer_id IN (?)",@importer_ids).
      where("commercial_invoice_lines.part_number = ?",part_number).
      where("entries.release_date is not null")
    cit = cit.where("commercial_invoice_lines.country_origin_code = ?",country_of_origin_code) unless country_of_origin_code.blank?
    cit = cit.order("entries.release_date DESC, commercial_invoice_tariffs.hts_code ASC").first
    if cit
      cil = cit.commercial_invoice_line
      return s.new(cil.part_number,cil.country_origin_code,cil.commercial_invoice.mfid,cit.hts_code)
    end
    nil
  end
end; end
