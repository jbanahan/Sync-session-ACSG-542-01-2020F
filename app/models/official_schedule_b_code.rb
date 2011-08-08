class OfficialScheduleBCode < ActiveRecord::Base

  #clears current schedule b list and reloads it from census file
  def self.load_from_census_file file_path
    OfficialScheduleBCode.transaction do 
      OfficialScheduleBCode.destroy_all
      IO.foreach(file_path) {|line|
        data_hash = {
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
        }
        osb = OfficialScheduleBCode.find_by_hts_code(data_hash[:hts_code])
        osb = OfficialScheduleBCode.new unless osb
        osb.update_attributes data_hash
      }
    end
    OfficialTariff.count
  end

end
