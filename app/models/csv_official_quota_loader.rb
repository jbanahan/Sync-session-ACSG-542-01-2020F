class CsvOfficialQuotaLoader
#download the spreadsheet from http://otexa.ita.doc.gov/scripts/correlation.exe
#remove rows above the column headings.
#remove trailing rows
#save as CSV and import using this class

  def self.go(file_path)
    c = Country.where(:iso_code=>"US").first
    CSV.foreach(file_path,{:headers=>true}) do |row|
      q = OfficialQuota.where(:country_id=>c,:hts_code=>row[1]).first
      q = OfficialQuota.new(:country_id=>c,:hts_code=>row[1]) if q.nil?
      q.category = row[0]
      q.unit_of_measure = row[2]
      q.square_meter_equivalent_factor = row[3]
      q.link #links with appropriate OfficialTariff
      q.save!
      puts q.hts_code
    end
  end
end
