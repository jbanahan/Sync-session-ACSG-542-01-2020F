class HtsTranslation < ActiveRecord::Base
  belongs_to :company
  belongs_to :country


  def self.translate_hts_number hts_number, country_iso_code, company = nil
    assoc = HtsTranslation.where(:hts_number => hts_number)
            .joins(:country)
            .where("countries.iso_code" => country_iso_code)

    # For cases where we have 1 company per system (polo, ann, etc) we don't really 
    # need the company id to do this translation.  For other systems, like vfitrack that
    # share product libraries, we do (the company id will end up being the importer_id)
    if company
      assoc = assoc.joins(:company).where("companies.id" => company.id)
    else 
      assoc = where(:company_id => nil)
    end

    assoc.pluck(:translated_hts_number).first
  end
end