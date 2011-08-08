class OfficialScheduleBCode < ActiveRecord::Base

  #clears current schedule b list and reloads it from census file
  def self.load_from_census_file file_path
    IO.foreach(file_path) {|line|
      OfficialScheduleBCode.create!(
        :hts_code => line[0,10].strip,
        :short_description => line[14,51].strip,
        :long_description => line[69,150].strip,
        :quantity_1 => line[224,3].strip,
        :quantity_2 => line[232,3].strip,
        :sitc_code => line[240,5].strip,
        :end_use_classification => line[250,5].strip,
        :usda_code => line[260,1].strip,
        :naics_classification => line[265,6].strip,
        :hitech_classification => line[276,2].strip
      )
    }
    OfficialTariff.count
  end

end
