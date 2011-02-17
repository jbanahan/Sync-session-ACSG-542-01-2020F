class CsvTariffLoader
  
  def initialize(country,file_path)
    @country = country
    @file_path = file_path  
  end
  
  def process
    #clear existing
    OfficialTariff.where(:country_id=>@country).destroy_all
    #load new
    CSV.foreach(@file_path, {:headers=>true}) do |row|
      OfficialTariff.create!(:country => @country,
        :hts_code => row[0].strip,
        :full_description => row[1].strip,
#        :special_rates => row[11].strip,
#       :unit_of_quantity => row[8].strip,
#       :general_rate => row[10].strip
      )
    end
  end
end
